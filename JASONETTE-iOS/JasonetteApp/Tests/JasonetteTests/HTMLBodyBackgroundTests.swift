import XCTest
import SwiftUI
@testable import Jasonette

private final class HTMLBackgroundURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixtures: [URL: Data] = [:]
    nonisolated(unsafe) private static var requests: [URL] = []

    static func install(_ values: [URL: Data]) {
        lock.lock()
        defer { lock.unlock() }
        fixtures = values
        requests = []
    }

    static var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lock.lock()
        let data = Self.fixtures[url]
        Self.requests.append(url)
        Self.lock.unlock()

        guard let data else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class HTMLBodyBackgroundTests: XCTestCase {
    private func decodeBody(_ json: String) throws -> JasonBody {
        try JSONDecoder().decode(JasonBody.self, from: Data(json.utf8))
    }

    private func fixtureData(_ relativePath: String) throws -> Data {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JasonetteTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // JasonetteApp
            .deletingLastPathComponent() // JASONETTE-iOS
            .deletingLastPathComponent() // repository
        return try Data(contentsOf: repository.appendingPathComponent(relativePath))
    }

    func testLegacyHTMLStyleBackgroundDecodesWithoutDroppingBodyContent() throws {
        let body = try decodeBody(#"""
        {
          "style": {
            "background": {"type":"html","text":"<svg id='clock'></svg>","css":"svg{display:block;}"},
            "color":"#ffffff",
            "padding":"12"
          },
          "header":{"title":"Clock"},
          "sections":[{"items":[{"type":"label","text":"Foreground"}]}],
          "layers":[{"type":"label","text":"Overlay"}],
          "footer":{"input":{"name":"message","placeholder":"Message"}}
        }
        """#)

        XCTAssertEqual(body.background?.dictionary?["type"]?.string, "html")
        XCTAssertEqual(body.background?.dictionary?["text"]?.string, "<svg id='clock'></svg>")
        XCTAssertEqual(body.background?.dictionary?["css"]?.string, "svg{display:block;}")
        XCTAssertNil(body.style?.background)
        XCTAssertEqual(body.style?.color, "#ffffff")
        XCTAssertEqual(body.style?.padding?.string, "12")
        XCTAssertEqual(body.header?.title, "Clock")
        XCTAssertEqual(body.sections?.first?.items?.first?.text, "Foreground")
        XCTAssertEqual(body.layers?.first?.text, "Overlay")
        XCTAssertEqual(body.footer?.input?.name, "message")
    }

    func testExplicitBodyBackgroundKeepsPrecedenceOverLegacyHTMLStyleBackground() throws {
        let body = try decodeBody(#"""
        {
          "background":"#123456",
          "style":{"background":{"type":"html","text":"<p>Legacy</p>"},"color":"#ffffff"}
        }
        """#)

        XCTAssertEqual(body.background?.string, "#123456")
        XCTAssertNil(body.style?.background)
        XCTAssertEqual(body.style?.color, "#ffffff")
    }

    func testColorAndImageStyleBackgroundsKeepExistingStringRepresentation() throws {
        for background in ["#123456", "https://example.com/background.png"] {
            let json = try JSONSerialization.data(withJSONObject: [
                "style": ["background": background, "color": "#ffffff"]
            ])
            let body = try JSONDecoder().decode(JasonBody.self, from: json)
            XCTAssertNil(body.background)
            XCTAssertEqual(body.style?.background, background)
            XCTAssertEqual(body.style?.color, "#ffffff")
        }
    }

    func testLegacyHTMLBackgroundSurvivesSemanticCodableRoundTrip() throws {
        let body = try decodeBody(#"""
        {
          "style":{"background":{"type":"html","text":"<svg id='clock'></svg>"},"opacity":0.5},
          "header":{"title":"Clock"},
          "sections":[{"items":[{"type":"label","text":"Foreground"}]}]
        }
        """#)
        let encoded = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(JasonBody.self, from: encoded)

        XCTAssertEqual(decoded.background, body.background)
        XCTAssertEqual(decoded.style?.opacity?.double, 0.5)
        XCTAssertEqual(decoded.header?.title, "Clock")
        XCTAssertEqual(decoded.sections?.first?.items?.first?.text, "Foreground")
    }

    func testLegacyHTMLBackgroundDoesNotHideUnrelatedMalformedStyle() {
        XCTAssertThrowsError(try decodeBody(#"""
        {"style":{"background":{"type":"html","text":"<p>Content</p>"},"color":{"bad":"shape"}}}
        """#))
        XCTAssertThrowsError(try decodeBody(#"{"style":{"background":123}}"#))
    }

    func testActualSVGIncludesLoadAndRenderClockBody() async throws {
        let directory = URL(string: "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/")!
        let svgURL = directory.appendingPathComponent("svg.json")
        let templateURL = directory.appendingPathComponent("template2.json")
        HTMLBackgroundURLProtocol.install([
            svgURL: try fixtureData("Jasonpedia/webcontainer/svg.json"),
            templateURL: try fixtureData("Jasonpedia/webcontainer/template2.json")
        ])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTMLBackgroundURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            HTMLBackgroundURLProtocol.install([:])
        }
        let viewModel = JasonetteViewModel(url: svgURL, loader: DocumentLoader(session: session))

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.documentURL, svgURL)
        let body = try XCTUnwrap(viewModel.renderedRoot?.body)
        XCTAssertEqual(body.header?.title, "SVG Clock")
        XCTAssertEqual(viewModel.navigationTitle, "SVG Clock")
        XCTAssertEqual(body.background?.dictionary?["type"]?.string, "html")
        let html = try XCTUnwrap(body.background?.dictionary?["text"]?.string)
        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("id='secondhand'"))
        XCTAssertTrue(html.contains("id='minutehand'"))
        XCTAssertTrue(html.contains("id='hourhand'"))
        XCTAssertTrue(HTMLBackgroundURLProtocol.requestedURLs.contains(svgURL))
        XCTAssertTrue(HTMLBackgroundURLProtocol.requestedURLs.contains(templateURL))
    }

    func testNavigationTitleUsesAuthoredBodyHeaderBeforeHead() async throws {
        let data = Data(#"""
        {"$jason":{"head":{"title":"Template title"},"body":{"header":{"title":"Authored title"},"sections":[]}}}
        """#.utf8)
        let document = try JSONDecoder().decode(JasonDocument.self, from: data)
        let viewModel = JasonetteViewModel(document: document)

        await viewModel.load()

        XCTAssertEqual(viewModel.navigationTitle, "Authored title")
    }

    func testNavigationTitleFallsBackToHeadAndEmpty() async throws {
        for (json, expected) in [
            (#"{"$jason":{"head":{"title":"Head title"},"body":{"sections":[]}}}"#, "Head title"),
            (#"{"$jason":{"body":{"sections":[]}}}"#, ""),
            (#"{"$jason":{"head":{"title":"Head title"},"body":{"header":{"title":""},"sections":[]}}}"#, "")
        ] {
            let document = try JSONDecoder().decode(JasonDocument.self, from: Data(json.utf8))
            let viewModel = JasonetteViewModel(document: document)
            await viewModel.load()
            XCTAssertEqual(viewModel.navigationTitle, expected)
        }
    }

    func testNavigationTitleTracksActionDrivenTemplateRenderUpdates() async throws {
        let data = Data(#"""
        {"$jason":{"head":{
          "title":"Template title",
          "data":{"title":"Initial title"},
          "templates":{"body":{"header":{"title":"{{title}}"},"sections":[]}}
        }}}
        """#.utf8)
        let document = try JSONDecoder().decode(JasonDocument.self, from: data)
        let viewModel = JasonetteViewModel(document: document)
        await viewModel.load()
        XCTAssertEqual(viewModel.navigationTitle, "Initial title")
        let actionData = Data(#"""
        {"type":"$set","options":{"title":"Updated title"},"success":{"type":"$render"}}
        """#.utf8)
        let action = try JSONDecoder().decode(JasonAction.self, from: actionData)

        await viewModel.actionDispatcher.execute(action)

        XCTAssertEqual(viewModel.navigationTitle, "Updated title")
        XCTAssertEqual(viewModel.renderedRoot?.head?.title, "Template title")
    }

    func testHTMLBackgroundUsesViewportAndPreservesAuthoredSource() throws {
        let body = try decodeBody(#"""
        {"style":{"background":{"type":"html","text":"<svg></svg>","css":"svg{display:block;}"}}}
        """#)
        let documentURL = URL(string: "https://example.com/docs/clock.json")!
        let html = try XCTUnwrap(HTMLComponent.background(in: body, documentURL: documentURL))

        XCTAssertEqual(html.text, "<svg></svg>")
        XCTAssertEqual(html.css, "svg{display:block;}")
        XCTAssertEqual(html.documentURL, documentURL)
        XCTAssertEqual(html.sizing, .viewport)
        XCTAssertFalse(html.allowsContentInteraction)
    }

    func testHTMLBackgroundURLUsesExistingResolutionAndSchemePolicy() throws {
        let documentURL = URL(string: "https://example.com/docs/clock.json")!
        let relativeBody = try decodeBody(#"{"background":{"type":"html","url":"clock.html"}}"#)
        let relativeHTML = try XCTUnwrap(HTMLComponent.background(in: relativeBody, documentURL: documentURL))
        XCTAssertEqual(relativeHTML.resolvedURL?.absoluteString, "https://example.com/docs/clock.html")

        let blockedBody = try decodeBody(#"{"background":{"type":"html","url":"javascript:alert(1)"}}"#)
        let blockedHTML = try XCTUnwrap(HTMLComponent.background(in: blockedBody, documentURL: documentURL))
        XCTAssertNil(blockedHTML.resolvedURL)

        let colorBody = try decodeBody(##"{"background":"#123456"}"##)
        XCTAssertNil(HTMLComponent.background(in: colorBody, documentURL: documentURL))
    }

    func testHTMLBackgroundSelectionRequiresHTMLTypeAndStringSource() throws {
        let cases: [([String: Any], Bool)] = [
            (["type": "html", "text": "<p>Content</p>"], true),
            (["type": "html", "url": "clock.html"], true),
            (["type": "html", "text": ""], true),
            (["type": "html", "css": "body{color:red;}"], false),
            (["type": "image", "text": "<p>Content</p>"], false),
            (["type": "html", "text": ["invalid": "shape"]], false),
            (["type": "html", "url": 123], false)
        ]
        for (background, selected) in cases {
            let data = try JSONSerialization.data(withJSONObject: ["background": background])
            let body = try JSONDecoder().decode(JasonBody.self, from: data)

            XCTAssertEqual(body.htmlBackground != nil, selected)
            XCTAssertEqual(HTMLComponent.background(in: body, documentURL: nil) != nil, selected)
            if selected { XCTAssertEqual(body.htmlBackground, body.background?.dictionary) }
        }
    }

    #if canImport(WebKit)
    func testViewportIgnoresHeightMeasurementAndContentSizingKeepsIt() {
        var height: CGFloat = 320
        let binding = Binding(get: { height }, set: { height = $0 })
        let coordinator = HTMLWebView.Coordinator(contentHeight: binding, sizing: .content)

        coordinator.applyMeasuredHeight(960)
        XCTAssertEqual(height, 960)

        coordinator.configure(contentHeight: binding, sizing: .viewport)
        coordinator.applyMeasuredHeight(1800)
        XCTAssertEqual(height, 960, "A late content measurement must not size a viewport background")

        coordinator.configure(contentHeight: binding, sizing: .content)
        coordinator.applyMeasuredHeight(480)
        XCTAssertEqual(height, 480)
    }
    #endif
}
