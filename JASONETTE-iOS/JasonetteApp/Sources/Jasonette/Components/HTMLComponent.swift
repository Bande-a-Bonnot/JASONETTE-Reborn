import SwiftUI
#if canImport(WebKit)
import WebKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
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
    enum Sizing: Equatable {
        case content
        case viewport
    }

    let text: String?
    let css: String?
    let url: String?
    let documentURL: URL?
    let allowsContentInteraction: Bool
    let sizing: Sizing

    @State private var contentHeight: CGFloat = Self.defaultHeight

    init(
        text: String?,
        css: String?,
        url: String?,
        documentURL: URL?,
        allowsContentInteraction: Bool = true,
        sizing: Sizing = .content
    ) {
        self.text = text
        self.css = css
        self.url = url
        self.documentURL = documentURL
        self.allowsContentInteraction = allowsContentInteraction
        self.sizing = sizing
    }

    init(component: JasonComponent, documentURL: URL?) {
        self.init(
            text: component.text,
            css: component.css,
            url: component.url,
            documentURL: documentURL,
            allowsContentInteraction: component.href == nil && component.action == nil
        )
    }

    var body: some View {
        Group {
            if sizing == .viewport {
                htmlContent.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                htmlContent.frame(minHeight: contentHeight)
            }
        }
        .allowsHitTesting(allowsContentInteraction)
        .accessibilityLabel("HTML content")
    }

    private var htmlContent: some View {
        Group {
            #if canImport(WebKit)
            if let url = resolvedURL {
                HTMLWebView(
                    source: .url(url),
                    contentHeight: $contentHeight,
                    allowsContentInteraction: allowsContentInteraction,
                    sizing: sizing
                )
            } else {
                HTMLWebView(
                    source: .html(Self.documentHTML(text: text ?? "", css: css), baseURL: baseURL),
                    contentHeight: $contentHeight,
                    allowsContentInteraction: allowsContentInteraction,
                    sizing: sizing
                )
            }
            #else
            Text(text ?? url ?? "")
                .foregroundColor(.secondary)
            #endif
        }
    }

    /// HTML body backgrounds occupy the document viewport, independent of content-height measurement.
    static func background(in body: JasonBody?, documentURL: URL?) -> HTMLComponent? {
        guard let background = body?.htmlBackground else { return nil }
        let text = background["text"]?.string
        let url = background["url"]?.string
        return HTMLComponent(
            text: text,
            css: background["css"]?.string,
            url: url,
            documentURL: documentURL,
            allowsContentInteraction: false,
            sizing: .viewport
        )
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
enum HTMLWebViewSource: Equatable {
    case html(String, baseURL: URL?)
    case url(URL)
}

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// Yield native touches to an outer Jasonette button when it owns activation.
@MainActor
final class HTMLContentWebView: WKWebView {
    var allowsContentInteraction = true

    #if os(macOS)
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard allowsContentInteraction else { return nil }
        return super.hitTest(point)
    }
    #else
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard allowsContentInteraction else { return nil }
        return super.hitTest(point, with: event)
    }
    #endif
}

struct HTMLWebView: PlatformViewRepresentable {
    let source: HTMLWebViewSource
    @Binding var contentHeight: CGFloat
    let allowsContentInteraction: Bool
    let sizing: HTMLComponent.Sizing

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight, sizing: sizing)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> HTMLContentWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ webView: HTMLContentWebView, context: Context) {
        update(webView, coordinator: context.coordinator)
    }
    #else
    func makeUIView(context: Context) -> HTMLContentWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: HTMLContentWebView, context: Context) {
        update(webView, coordinator: context.coordinator)
    }
    #endif

    func makeWebView(coordinator: Coordinator) -> HTMLContentWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = HTMLContentWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.allowsContentInteraction = allowsContentInteraction
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

    func update(_ webView: HTMLContentWebView, coordinator: Coordinator) {
        webView.allowsContentInteraction = allowsContentInteraction
        coordinator.configure(contentHeight: $contentHeight, sizing: sizing)
        guard coordinator.loadedSource != source else { return }
        coordinator.loadedSource = source

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
        private(set) var sizing: HTMLComponent.Sizing

        init(contentHeight: Binding<CGFloat>, sizing: HTMLComponent.Sizing) {
            _contentHeight = contentHeight
            self.sizing = sizing
        }

        func configure(contentHeight: Binding<CGFloat>, sizing: HTMLComponent.Sizing) {
            _contentHeight = contentHeight
            self.sizing = sizing
        }

        func applyMeasuredHeight(_ height: CGFloat) {
            guard sizing == .content else { return }
            contentHeight = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateHeight(for: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateHeight(for: webView)
        }

        private func updateHeight(for webView: WKWebView) {
            guard sizing == .content else { return }
            let script = "Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement ? document.documentElement.scrollHeight : 0, document.body ? document.body.offsetHeight : 0, document.documentElement ? document.documentElement.offsetHeight : 0)"
            webView.evaluateJavaScript(script) { value, _ in
                let height = HTMLComponent.sanitizedHeight(value)
                Task { @MainActor in
                    self.applyMeasuredHeight(height)
                }
            }
        }
    }
}
#endif
