import SwiftUI
import WebKit

struct VelloroWebPanel: UIViewRepresentable {
    let urlString: String
    /// Our own host — the tracker hop, which must never be remembered as a resume point.
    /// The privacy sheet passes none, which also switches remembering off for it.
    var trackerHost: String = ""
    /// Where to go if `urlString` is a resumed address that has since gone dead.
    /// nil when the panel already started at the tracker link (and for the privacy sheet).
    var fallbackAddress: String? = nil
    /// Fires once the page starts rendering, so the caller can lift the splash overlay.
    var onFirstPaint: (() -> Void)? = nil
    /// Fires when nothing loads at all — live or cached. The caller shows the game instead.
    var onDeadEnd: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        var onDeadEnd: (() -> Void)?
        var trackerHost = ""
        var fallbackAddress: String?
        /// What the panel was asked to load first — the cache candidate when it was a
        /// resumed address.
        var initialAddress = ""
        private var fired = false
        private var triedFallback = false
        private var triedCache = false
        private var urlObservation: NSKeyValueObservation?

        deinit { urlObservation?.invalidate() }

        /// A same-document navigation — an SPA tab via `pushState`, a `#hash` tab — fires
        /// no navigation delegate callback, so `didCommit` never sees it and the resume
        /// address would freeze on whatever loaded last. `url` is KVO-compliant and moves
        /// for both, and `remember` is idempotent, so this simply covers more.
        func watchAddress(of panel: WKWebView) {
            urlObservation?.invalidate()
            urlObservation = panel.observe(\.url, options: [.new]) { [weak self] observed, _ in
                guard let self = self else { return }
                VelloroPanelSession.remember(observed.url, trackerHost: self.trackerHost)
            }
        }

        // didCommit, not didFinish: on a heavy page didFinish lands seconds after it is
        // already visible and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            VelloroPanelSession.remember(webView.url, trackerHost: trackerHost)
            fire()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            VelloroPanelSession.remember(webView.url, trackerHost: trackerHost)
            // The jar is at its most interesting the moment a page settles: a sign-in
            // POST has landed by now.
            VelloroPanelCookies.snapshot()
        }

        // A real failure must also lift the overlay, or the splash hangs forever.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let failure = error as NSError
            // A cancelled load is what an ordinary redirect looks like here.
            if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
            // After the first paint a failed navigation is an ordinary failed navigation
            // inside a working session: WebKit shows its error and the user can go back.
            // Recovery is only for a panel that never got off the ground — otherwise this
            // would yank a browsing user back into the game.
            guard !fired else { return }
            recover(webView)
        }

        /// resumed address live -> tracker link live -> the same address from the on-disk
        /// cache -> give up and hand back the game. Never leave the user on WebKit's error
        /// page: fullscreen, no back, no reload, nothing to act on.
        private func recover(_ webView: WKWebView) {
            if !triedFallback, let fallback = fallbackAddress, let url = URL(string: fallback) {
                triedFallback = true
                VelloroPanelSession.forget()          // stop resuming a dead address
                webView.load(URLRequest(url: url))
                return
            }
            // A stale page from disk still shows the user their account; an error page
            // shows them nothing they can act on. Only for a real page — the tracker link
            // is a 302 with nothing cached worth having.
            if !triedCache, fallbackAddress != nil, let url = URL(string: initialAddress) {
                triedCache = true
                webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataDontLoad,
                                        timeoutInterval: 15))
                return
            }
            onDeadEnd?()
        }

        private func fire() {
            guard !fired else { return }
            fired = true
            onFirstPaint?()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Explicit because the signed-in session depends on it: the DEFAULT store is the
        // persistent, on-disk one. Never .nonPersistent().
        configuration.websiteDataStore = .default()

        let panel = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
        context.coordinator.initialAddress = urlString
        panel.navigationDelegate = context.coordinator
        context.coordinator.watchAddress(of: panel)
        panel.allowsBackForwardNavigationGestures = true
        panel.scrollView.bounces = true
        // Required: the frame runs under the home indicator, and this is what insets
        // scrollable content back out of it. Never .never.
        panel.scrollView.contentInsetAdjustmentBehavior = .always
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.scrollView.backgroundColor = .black
        // The branch presenting this runs dark so the status bar glyphs turn white. Pin
        // the page itself back to light so that trait never reaches the site.
        panel.overrideUserInterfaceStyle = .light

        // Cookies FIRST, then load. The other order signs the user out on every cold
        // start, and the splash is still up so the wait is invisible.
        let address = urlString
        VelloroPanelCookies.restore { [weak panel] in
            guard let panel = panel, let url = URL(string: address) else { return }
            panel.load(URLRequest(url: url))
        }
        return panel
    }

    // Must never reload: that would restart the page on every SwiftUI re-render.
    // Refreshing the callbacks is the only thing allowed here.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
    }
}

// MARK: - Resume address

/// Remembers the last page the panel was really on, so a cold start resumes there
/// instead of re-running the redirect chain from the top.
enum VelloroPanelSession {
    private static let addressKey = "panel.resume.address"
    private static let stampKey   = "panel.resume.stamp"
    /// Past this a resumed address is likelier to be stale than useful.
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 30

    static func remember(_ url: URL?, trackerHost: String) {
        // No tracker host means this is not the launch panel — the privacy sheet passes
        // none, which switches remembering off for it. Without this guard the next launch
        // would resume the privacy page instead of the offer.
        guard !trackerHost.isEmpty else { return }
        guard let url = url, url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        // Never store our own hop: resuming it would re-run the very chain this avoids.
        if host == trackerHost || host.hasSuffix("." + trackerHost) { return }
        UserDefaults.standard.set(url.absoluteString, forKey: addressKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    static func resumeAddress() -> String? {
        guard let address = UserDefaults.standard.string(forKey: addressKey),
              let url = URL(string: address), url.host != nil else { return nil }
        let stamp = UserDefaults.standard.double(forKey: stampKey)
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < maxAge else { return nil }
        return address
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: addressKey)
        UserDefaults.standard.removeObject(forKey: stampKey)
    }
}

// MARK: - Cookie mirror

/// Mirrors the WebKit cookie jar out to `UserDefaults` and back. A cookie with no expiry
/// (a plain PHPSESSID) lives only in the networking process and dies with it; this is
/// what keeps a sign-in alive across a cold start.
enum VelloroPanelCookies {
    private static let key = "panel.cookies"
    /// Expiry given to a cookie that had none. Long enough to outlive ordinary use.
    private static let sessionLifetime: TimeInterval = 60 * 60 * 24 * 180
    /// WebKit has been seen to swallow a `setCookie` completion. Never let that hold a
    /// launch: past this the page loads regardless.
    private static let restoreGrace: TimeInterval = 1.5

    static func snapshot() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let payload: [[String: String]] = cookies.map { cookie in
                let expiry = cookie.expiresDate ?? Date().addingTimeInterval(sessionLifetime)
                return [
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain,
                    "path": cookie.path.isEmpty ? "/" : cookie.path,
                    "secure": cookie.isSecure ? "1" : "0",
                    "expires": String(expiry.timeIntervalSince1970)
                ]
            }
            // Wholesale overwrite, so a sign-out that empties the jar empties the mirror
            // too and cannot resurrect a dead session on the next launch.
            UserDefaults.standard.set(payload, forKey: key)
        }
    }

    /// Re-injects the mirror and then calls back. The caller MUST wait for this before
    /// the first load: a request that goes out early is the one that arrives signed out.
    static func restore(completion: @escaping () -> Void) {
        guard let payload = UserDefaults.standard.array(forKey: key) as? [[String: String]],
              !payload.isEmpty else { completion(); return }

        let store = WKWebsiteDataStore.default().httpCookieStore
        let now = Date()
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            completion()
        }

        let group = DispatchGroup()
        var queued = 0
        for entry in payload {
            guard let name = entry["name"], let value = entry["value"],
                  let domain = entry["domain"], let path = entry["path"],
                  let raw = entry["expires"], let seconds = TimeInterval(raw) else { continue }
            let expiry = Date(timeIntervalSince1970: seconds)
            guard expiry > now else { continue }
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name, .value: value, .domain: domain, .path: path, .expires: expiry
            ]
            if entry["secure"] == "1" { props[.secure] = "TRUE" }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            queued += 1
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }

        guard queued > 0 else { finish(); return }
        group.notify(queue: .main) { finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreGrace) { finish() }
    }
}
