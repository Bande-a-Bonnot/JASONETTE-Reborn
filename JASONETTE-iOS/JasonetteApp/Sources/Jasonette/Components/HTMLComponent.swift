import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// Renders Jasonette `type: "html"` components.
///
/// Original Jasonette fixtures use two shapes:
/// - inline HTML in `text`, optionally with sibling `css`
/// - URL-backed HTML in `url`
///
/// Inline HTML is wrapped in a minimal document when authored as a fragment so
/// WebKit gets a viewport and predictable zero-margin body. The web view reports
/// document height back into SwiftUI so HTML components placed inside Jasonette's
/// outer ScrollView do not collapse to zero height.
@MainActor
struct HTMLComponent: View {
    let text: String?
    let css: String?
    let url: String?
    let documentURL: URL?

    @State private var contentHeight: CGFloat = Self.defaultHeight

    var body: some View {
        Group {
            #if canImport(WebKit)
            if let url = resolvedURL {
                HTMLWebView(source: .url(url), contentHeight: $contentHeight)
            } else {
                HTMLWebView(
                    source: .html(Self.documentHTML(text: text ?? "", css: css), baseURL: baseURL),
                    contentHeight: $contentHeight
                )
            }
            #else
            Text(text ?? url ?? "")
                .foregroundColor(.secondary)
            #endif
        }
        .frame(minHeight: contentHeight)
        .accessibilityLabel("HTML content")
    }

    var resolvedURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return JasonURL.resolve(url, against: documentURL, allowedSchemes: ["http", "https"])
    }

    var baseURL: URL? {
        documentURL?.deletingLastPathComponent()
    }

    static let defaultHeight: CGFloat = 320
    static let minimumHeight: CGFloat = 44

    static func documentHTML(text: String, css: String?) -> String {
        let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
        let style = "<style>html,body{margin:0;padding:0;width:100%;}\(css ?? "")</style>"
        let headContent = viewport + style
        let lowercased = text.lowercased()

        guard lowercased.contains("<html") || lowercased.contains("<!doctype") else {
            return "<!doctype html><html><head>\(headContent)</head><body>\(text)</body></html>"
        }

        if lowercased.contains("</head>") {
            return text.replacingOccurrences(of: "</head>", with: "\(headContent)</head>", options: [.caseInsensitive])
        }

        if let htmlStart = text.range(of: "<html", options: [.caseInsensitive]),
           let tagEnd = text[htmlStart.upperBound...].firstIndex(of: ">") {
            var output = text
            output.insert(contentsOf: "<head>\(headContent)</head>", at: text.index(after: tagEnd))
            return output
        }

        return "<!doctype html><html><head>\(headContent)</head><body>\(text)</body></html>"
    }

    static func sanitizedHeight(_ rawHeight: Any?) -> CGFloat {
        guard let number = rawHeight as? NSNumber else { return defaultHeight }
        let height = CGFloat(truncating: number)
        guard height.isFinite else { return defaultHeight }
        return max(minimumHeight, height)
    }
}

#if canImport(WebKit)
private enum HTMLWebViewSource: Equatable {
    case html(String, baseURL: URL?)
    case url(URL)
}

#if os(macOS)
private typealias PlatformViewRepresentable = NSViewRepresentable
#else
private typealias PlatformViewRepresentable = UIViewRepresentable
#endif

private struct HTMLWebView: PlatformViewRepresentable {
    let source: HTMLWebViewSource
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        update(webView, context: context)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        update(webView, context: context)
    }
    #endif

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #else
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        #endif
        return webView
    }

    private func update(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedSource != source else { return }
        context.coordinator.loadedSource = source

        switch source {
        case let .html(html, baseURL):
            webView.loadHTMLString(html, baseURL: baseURL)
        case let .url(url):
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var contentHeight: CGFloat
        var loadedSource: HTMLWebViewSource?

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateHeight(for: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateHeight(for: webView)
        }

        private func updateHeight(for webView: WKWebView) {
            let script = "Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement ? document.documentElement.scrollHeight : 0, document.body ? document.body.offsetHeight : 0, document.documentElement ? document.documentElement.offsetHeight : 0)"
            webView.evaluateJavaScript(script) { value, _ in
                let height = HTMLComponent.sanitizedHeight(value)
                Task { @MainActor in
                    self.contentHeight = height
                }
            }
        }
    }
}
#endif
