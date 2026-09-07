import SwiftUI
import WebKit

struct VelloroWebPanel: UIViewRepresentable {
    let urlString: String
    /// Fires once the page starts rendering, so the caller can lift the splash overlay.
    var onFirstPaint: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        private var fired = false

        // didCommit, not didFinish: on a heavy page didFinish lands seconds after it is
        // already visible and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { fire() }

        // A real failure must also lift the overlay, or the splash hangs forever.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let failure = error as NSError
            // A cancelled load is what an ordinary redirect looks like here.
            if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
            fire()
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

        let panel = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onFirstPaint = onFirstPaint
        panel.navigationDelegate = context.coordinator
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

        if let url = URL(string: urlString) {
            panel.load(URLRequest(url: url))
        }
        return panel
    }

    // Must never reload: that would restart the page on every SwiftUI re-render.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
    }
}
