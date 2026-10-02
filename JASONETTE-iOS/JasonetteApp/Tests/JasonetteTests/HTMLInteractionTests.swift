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
            XCTAssertFalse(HTMLComponent(component: row, documentURL: viewModel.documentURL).allowsContentInteraction)

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
