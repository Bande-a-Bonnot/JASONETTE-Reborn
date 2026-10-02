import XCTest
import SwiftUI
#if canImport(WebKit)
import WebKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#endif
@testable import Jasonette

@MainActor
final class HTMLInteractionTests: XCTestCase {
    private func component(_ json: String) throws -> JasonComponent {
        try JSONDecoder().decode(JasonComponent.self, from: Data(json.utf8))
    }

    func testOuterHrefAndActionYieldEmbeddedInteraction() throws {
        for json in [
            #"{"type":"html","text":"<p>Row</p>","href":{"url":"details.json"}}"#,
            #"{"type":"html","text":"<p>Row</p>","action":{"type":"$util.alert"}}"#,
            #"{"type":"html","url":"row.html","href":{"url":"details.json"},"action":{"type":"$util.alert"}}"#
        ] {
            let html = HTMLComponent(component: try component(json), documentURL: nil)
            XCTAssertFalse(html.allowsContentInteraction)
            XCTAssertEqual(html.sizing, .content)
        }
    }

    func testPlainInlineAndURLHTMLKeepEmbeddedInteraction() throws {
        for json in [
            #"{"type":"html","text":"<button>Inner button</button>"}"#,
            #"{"type":"html","url":"article.html"}"#
        ] {
            let html = HTMLComponent(component: try component(json), documentURL: URL(string: "https://example.com/index.json"))
            XCTAssertTrue(html.allowsContentInteraction)
            XCTAssertEqual(html.sizing, .content)
        }
    }

    func testAuthoredHTMLHeightUsesExactBoundsIncludingBelowMeasurementMinimum() throws {
        for (value, expected) in [(#""120""#, CGFloat(120)), ("20", CGFloat(20))] {
            let row = try component("{\"type\":\"html\",\"text\":\"<p>Row</p>\",\"style\":{\"height\":\(value)}}")
            let html = HTMLComponent(component: row, documentURL: nil)

            XCTAssertEqual(html.sizing, .fixed(expected))
        }
    }

    func testHTMLHeightUsesResolvedClassStyleAndInlinePrecedence() throws {
        let classStyle = try JSONDecoder().decode(JasonStyle.self, from: Data(#"{"height":"120"}"#.utf8))
        for (json, expected) in [
            (#"{"type":"html","class":"tile","text":"<p>Row</p>"}"#, CGFloat(120)),
            (#"{"type":"html","class":"tile","text":"<p>Row</p>","style":{"height":"80"}}"#, CGFloat(80))
        ] {
            let row = try component(json)
            let style = JasonStyle.resolve(for: row, headStyles: ["tile": classStyle])
            let html = HTMLComponent(component: row, documentURL: nil, style: style)

            XCTAssertEqual(html.sizing, .fixed(expected))
        }
    }

    func testFixedHTMLHeightSubtractsVerticalPaddingWithDirectionalPrecedence() throws {
        for (styleJSON, expected) in [
            (#"{"height":"120","padding_top":"20"}"#, CGFloat(100)),
            (#"{"height":"120","padding":"10"}"#, CGFloat(100)),
            (#"{"height":"120","padding":"10","padding_top":"20"}"#, CGFloat(90)),
            (#"{"height":"120","padding":"10","padding_bottom":"0"}"#, CGFloat(110)),
            (#"{"height":"120","padding":"10","padding_top":"0","padding_bottom":"5"}"#, CGFloat(115)),
            (#"{"height":"20","padding_top":"30","padding_bottom":"5"}"#, CGFloat(0))
        ] {
            let row = try component("{\"type\":\"html\",\"text\":\"<p>Row</p>\",\"style\":\(styleJSON)}")
            let html = HTMLComponent(component: row, documentURL: nil)

            XCTAssertEqual(html.sizing, .fixed(expected), styleJSON)
        }
    }

    func testFixedHTMLHeightUsesResolvedClassPaddingAndInlineEdgeOverrides() throws {
        let classStyle = try JSONDecoder().decode(
            JasonStyle.self,
            from: Data(#"{"height":"120","padding":"10","padding_top":"20"}"#.utf8)
        )
        let row = try component(#"{"type":"html","class":"tile","style":{"padding_top":"0"}}"#)
        let style = JasonStyle.resolve(for: row, headStyles: ["tile": classStyle])
        let html = HTMLComponent(component: row, documentURL: nil, style: style)

        XCTAssertEqual(html.sizing, .fixed(110))
    }

    func testActualHTMLMenuRowsKeepAuthoredHrefAndEmitTheirPushes() async throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repository.appendingPathComponent("Jasonpedia/webcontainer/index.json"))
        let document = try JSONDecoder().decode(JasonDocument.self, from: data)
        var requests: [NavigationRequest] = []
        let viewModel = JasonetteViewModel(document: document, onNavigate: { requests.append($0) })
        await viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loaded)
        let rows = try XCTUnwrap(viewModel.renderedRoot?.body?.sections?.first?.items)

        for (name, file) in [("svg", "svg.json"), ("lots of web containers", "lots.json")] {
            let row = try XCTUnwrap(rows.first { $0.text?.contains(">\(name)</div>") == true })
            let href = try XCTUnwrap(row.href)
            XCTAssertEqual(row.type, "html")
            XCTAssertEqual(href.url, "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/\(file)")
            let html = HTMLComponent(component: row, documentURL: viewModel.documentURL)
            XCTAssertFalse(html.allowsContentInteraction)
            XCTAssertEqual(html.sizing, .fixed(120))

            viewModel.handleHref(href)

            guard case let .push(url, params) = requests.last else {
                return XCTFail("Expected an in-app push for \(name)")
            }
            XCTAssertEqual(url.absoluteString, href.url)
            XCTAssertTrue(params.isEmpty)
        }
        XCTAssertEqual(requests.count, 2)
    }

    #if canImport(WebKit)
    func testAuthoredAndViewportHeightIgnoreMeasurementsWhileUnstyledHTMLKeepsThem() {
        var height = HTMLComponent.defaultHeight
        let binding = Binding(get: { height }, set: { height = $0 })
        let coordinator = HTMLWebView.Coordinator(contentHeight: binding, sizing: .fixed(120))

        coordinator.applyMeasuredHeight(960)
        XCTAssertEqual(height, 320, "Authored bounds must ignore the larger DOM scroll height")

        coordinator.configure(contentHeight: binding, sizing: .viewport)
        coordinator.applyMeasuredHeight(1800)
        XCTAssertEqual(height, 320, "Decorative backgrounds remain independent of DOM height")

        coordinator.configure(contentHeight: binding, sizing: .content)
        coordinator.applyMeasuredHeight(480)
        XCTAssertEqual(height, 480, "Unstyled HTML retains measured content sizing")
    }

    func testNativeWebContentYieldsHitToParentForOuterActivation() {
        let source = HTMLWebViewSource.html("<button>Content</button>", baseURL: nil)
        let representable = HTMLWebView(
            source: source,
            contentHeight: .constant(320),
            allowsContentInteraction: false,
            sizing: .content
        )
        let coordinator = representable.makeCoordinator()
        let webView = representable.makeWebView(coordinator: coordinator)
        webView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        #if os(macOS)
        let parent = NSView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        parent.addSubview(webView)
        XCTAssertNil(webView.hitTest(NSPoint(x: 20, y: 20)))
        XCTAssertTrue(parent.hitTest(NSPoint(x: 20, y: 20)) === parent)
        #else
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        parent.addSubview(webView)
        XCTAssertNil(webView.hitTest(CGPoint(x: 20, y: 20), with: nil))
        XCTAssertTrue(parent.hitTest(CGPoint(x: 20, y: 20), with: nil) === parent)
        #endif
        XCTAssertTrue(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        webView.removeFromSuperview()
    }

    func testNativeInteractionChangesWithoutReloadingSameHTMLSource() {
        let source = HTMLWebViewSource.html("<button>Content</button>", baseURL: nil)
        let outerActivation = HTMLWebView(
            source: source,
            contentHeight: .constant(320),
            allowsContentInteraction: false,
            sizing: .content
        )
        let coordinator = outerActivation.makeCoordinator()
        let webView = outerActivation.makeWebView(coordinator: coordinator)
        webView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        // Mark the source as loaded so the real update follows its no-reload path.
        coordinator.loadedSource = source
        let plainHTML = HTMLWebView(
            source: source,
            contentHeight: .constant(320),
            allowsContentInteraction: true,
            sizing: .content
        )

        plainHTML.update(webView, coordinator: coordinator)

        XCTAssertTrue(webView.allowsContentInteraction)
        XCTAssertEqual(coordinator.loadedSource, source)
        XCTAssertNil(webView.url)
        #if os(macOS)
        XCTAssertNotNil(webView.hitTest(NSPoint(x: 20, y: 20)))
        #else
        XCTAssertNotNil(webView.hitTest(CGPoint(x: 20, y: 20), with: nil))
        #endif

        outerActivation.update(webView, coordinator: coordinator)

        XCTAssertFalse(webView.allowsContentInteraction)
        #if os(macOS)
        XCTAssertNil(webView.hitTest(NSPoint(x: 20, y: 20)))
        #else
        XCTAssertNil(webView.hitTest(CGPoint(x: 20, y: 20), with: nil))
        #endif
        XCTAssertEqual(coordinator.loadedSource, source)
        XCTAssertNil(webView.url)
    }
    #endif
}
