import XCTest
@testable import Jasonette

final class DocumentLoaderTests: XCTestCase {
    private var loader: DocumentLoader!
    private var stubSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        stubSession = URLSession(configuration: config)
        loader = DocumentLoader(session: stubSession)
    }

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.redirectHandler = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private let sampleJSON = """
    {
        "$jason": {
            "head": {"title": "Sample"},
            "body": {"sections": [{"items": [{"type": "label", "text": "Hello"}]}]}
        }
    }
    """

    private func stub(statusCode: Int, body: String = "{}") {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(body.utf8))
        }
    }

    private func loadFixtureString(_ relativePath: String) throws -> String {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let repoRoot = testDir
            .deletingLastPathComponent() // JasonetteTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> JasonetteApp/
            .deletingLastPathComponent() // JasonetteApp/ -> JASONETTE-iOS/
            .deletingLastPathComponent() // JASONETTE-iOS/ -> JASONETTE-Reborn/
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Load from URL

    func testLoadReturnsDocumentOn200() async throws {
        stub(statusCode: 200, body: sampleJSON)
        let url = URL(string: "https://example.com/doc.json")!
        let doc = try await loader.load(from: url)
        XCTAssertEqual(doc.jason.head?.title, "Sample")
    }

    func testLoadDocumentHasSections() async throws {
        stub(statusCode: 200, body: sampleJSON)
        let url = URL(string: "https://example.com/doc.json")!
        let doc = try await loader.load(from: url)
        XCTAssertEqual(doc.jason.body?.sections?.count, 1)
        XCTAssertEqual(doc.jason.body?.sections?.first?.items?.first?.text, "Hello")
    }

    func testLoadWithMetadataReturnsResponseURL() async throws {
        let finalURL = URL(string: "https://cdn.example.com/final/doc.json")!
        StubURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: finalURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(self.sampleJSON.utf8))
        }
        let loaded = try await loader.loadWithMetadata(from: URL(string: "https://example.com/doc.json")!)
        XCTAssertEqual(loaded.document.jason.head?.title, "Sample")
        XCTAssertEqual(loaded.url, finalURL)
    }

    func testLoadWithMetadataRejectsDisallowedResponseURLScheme() async {
        let requestedURL = URL(string: "https://example.com/doc.json")!
        StubURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "file:///tmp/doc.json")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(self.sampleJSON.utf8))
        }
        do {
            _ = try await loader.loadWithMetadata(from: requestedURL)
            XCTFail("Expected blockedURL error")
        } catch DocumentLoader.DocumentError.blockedURL {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadRejectsDisallowedResponseURLScheme() async {
        let requestedURL = URL(string: "https://example.com/doc.json")!
        StubURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "file:///tmp/doc.json")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(self.sampleJSON.utf8))
        }
        do {
            _ = try await loader.load(from: requestedURL)
            XCTFail("Expected blockedURL error")
        } catch DocumentLoader.DocumentError.blockedURL {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadWithMetadataFollowsHTTPSRedirectAndReturnsFinalURL() async throws {
        let startURL = URL(string: "https://example.com/start.json")!
        let finalURL = URL(string: "https://cdn.example.com/final.json")!
        StubURLProtocol.redirectHandler = { request in
            request.url == startURL ? URLRequest(url: finalURL) : nil
        }
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, finalURL)
            let response = HTTPURLResponse(
                url: finalURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(self.sampleJSON.utf8))
        }

        let loaded = try await loader.loadWithMetadata(from: startURL)
        XCTAssertEqual(loaded.url, finalURL)
        XCTAssertEqual(loaded.document.jason.head?.title, "Sample")
    }

    func testRedirectValidatorAllowsHTTPSRedirects() {
        let validator = DocumentLoader.RedirectSchemeValidator()
        let request = URLRequest(url: URL(string: "https://example.com/final.json")!)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/start.json")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/final.json"]
        )!
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com/start.json")!)
        defer { task.cancel() }

        let expectation = expectation(description: "redirect completion")
        validator.urlSession(.shared, task: task, willPerformHTTPRedirection: response, newRequest: request) { redirectedRequest in
            XCTAssertEqual(redirectedRequest?.url, request.url)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(validator.didBlockRedirect)
    }

    func testRedirectValidatorBlocksDisallowedRedirectSchemes() {
        let validator = DocumentLoader.RedirectSchemeValidator()
        let request = URLRequest(url: URL(string: "file:///tmp/final.json")!)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/start.json")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "file:///tmp/final.json"]
        )!
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com/start.json")!)
        defer { task.cancel() }

        let expectation = expectation(description: "redirect completion")
        validator.urlSession(.shared, task: task, willPerformHTTPRedirection: response, newRequest: request) { redirectedRequest in
            XCTAssertNil(redirectedRequest)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(validator.didBlockRedirect)
    }

    func testLoadThrowsOn404() async {
        stub(statusCode: 404)
        let url = URL(string: "https://example.com/missing.json")!
        do {
            _ = try await loader.load(from: url)
            XCTFail("Expected httpError")
        } catch DocumentLoader.DocumentError.httpError(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadThrowsOn500() async {
        stub(statusCode: 500)
        let url = URL(string: "https://example.com/error.json")!
        do {
            _ = try await loader.load(from: url)
            XCTFail("Expected httpError")
        } catch DocumentLoader.DocumentError.httpError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadThrowsOn301() async {
        stub(statusCode: 301)
        let url = URL(string: "https://example.com/redirect.json")!
        do {
            _ = try await loader.load(from: url)
            XCTFail("Expected httpError")
        } catch DocumentLoader.DocumentError.httpError(let code) {
            XCTAssertEqual(code, 301)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Decode from Data

    func testDecodeFromData() throws {
        let doc = try loader.decode(Data(sampleJSON.utf8))
        XCTAssertEqual(doc.jason.head?.title, "Sample")
    }

    func testDecodeFromDataWithDataField() throws {
        let json = """
        {"$jason": {"head": {"title": "Data", "data": {"key": "value"}}, "body": null}}
        """
        let doc = try loader.decode(Data(json.utf8))
        XCTAssertEqual(doc.jason.head?.data?["key"]?.string, "value")
    }

    func testDecodeInvalidDataThrows() {
        XCTAssertThrowsError(try loader.decode(Data("{bad json}".utf8)))
    }

    func testDecodeEmptyDataThrows() {
        XCTAssertThrowsError(try loader.decode(Data()))
    }

    // MARK: - Decode from String

    func testDecodeFromValidJSONString() throws {
        let doc = try loader.decode(sampleJSON)
        XCTAssertEqual(doc.jason.head?.title, "Sample")
    }

    func testDecodeFromInvalidJSONStringThrows() {
        XCTAssertThrowsError(try loader.decode("{not: valid}"))
    }

    // MARK: - Document structure

    func testDecodeDocumentWithActions() throws {
        let json = """
        {
            "$jason": {
                "head": {
                    "title": "Actions",
                    "actions": {
                        "$load": {"type": "$set", "options": {"loaded": true}}
                    }
                },
                "body": {"sections": []}
            }
        }
        """
        let doc = try loader.decode(Data(json.utf8))
        XCTAssertNotNil(doc.jason.head?.actions?["$load"])
        XCTAssertEqual(doc.jason.head?.actions?["$load"]?.type, "$set")
    }

    func testDecodeDocumentWithStyles() throws {
        let json = """
        {
            "$jason": {
                "head": {
                    "title": "Styles",
                    "styles": {
                        "primary": {"color": "#ff0000", "size": 16}
                    }
                },
                "body": {"sections": []}
            }
        }
        """
        let doc = try loader.decode(Data(json.utf8))
        XCTAssertEqual(doc.jason.head?.styles?["primary"]?.color, "#ff0000")
        XCTAssertEqual(doc.jason.head?.styles?["primary"]?.size?.int, 16)
    }

    func testDecodeDocumentWithNestedComponents() throws {
        let json = """
        {
            "$jason": {
                "head": {"title": "Nested"},
                "body": {
                    "sections": [{
                        "items": [{
                            "type": "vertical",
                            "components": [
                                {"type": "label", "text": "Inner"}
                            ]
                        }]
                    }]
                }
            }
        }
        """
        let doc = try loader.decode(Data(json.utf8))
        let item = doc.jason.body?.sections?.first?.items?.first
        XCTAssertEqual(item?.type, "vertical")
        XCTAssertEqual(item?.components?.first?.text, "Inner")
    }

    // MARK: - URL scheme validation

    func testLoadRejectsFileURL() async {
        let url = URL(string: "file:///etc/passwd")!
        do {
            _ = try await loader.load(from: url)
            XCTFail("Expected blockedURL error")
        } catch DocumentLoader.DocumentError.blockedURL {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadRejectsFTPURL() async {
        let url = URL(string: "ftp://example.com/file.json")!
        do {
            _ = try await loader.load(from: url)
            XCTFail("Expected blockedURL error")
        } catch DocumentLoader.DocumentError.blockedURL {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadAllowsHTTP() async throws {
        stub(statusCode: 200, body: sampleJSON)
        let url = URL(string: "http://example.com/doc.json")!
        let doc = try await loader.load(from: url)
        XCTAssertEqual(doc.jason.head?.title, "Sample")
    }

    // MARK: - Legacy includes

    func testLoadResolvingIncludesWithMetadataExpandsJasonpediaWebContainerIframe() async throws {
        let base = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer"
        let iframe = try loadFixtureString("Jasonpedia/webcontainer/iframe.json")
        let template = try loadFixtureString("Jasonpedia/webcontainer/template.json")
        StubURLProtocol.requestHandler = { request in
            let body: String
            switch request.url?.absoluteString {
            case "\(base)/iframe.json": body = iframe
            case "\(base)/template.json": body = template
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: URL(string: "\(base)/iframe.json")!)
        let bodyTemplate = try XCTUnwrap(loaded.document.jason.head?.templates?["body"]?.dictionary)
        let header = try XCTUnwrap(bodyTemplate["header"]?.dictionary)
        let style = try XCTUnwrap(bodyTemplate["style"]?.dictionary)
        let background = try XCTUnwrap(style["background"]?.dictionary)

        XCTAssertEqual(header["title"]?.string, "iframe")
        XCTAssertEqual(background["text"]?.string?.contains("hardbound.co"), true)
        XCTAssertEqual(background["action"]?.dictionary?["type"]?.string, "$default")
    }

    func testLoadResolvingIncludesWithMetadataResolvesNestedRelativesAgainstIncludingDocument() async throws {
        let rootURL = URL(string: "https://example.com/root/index.json")!
        let partialURL = URL(string: "https://example.com/root/partials/template.json")!
        let leafURL = URL(string: "https://example.com/root/partials/leaf.json")!
        var requested: [URL] = []
        StubURLProtocol.requestHandler = { request in
            requested.append(request.url!)
            let body: String
            switch request.url {
            case rootURL:
                body = #"{"+":"partials/template.json","title":"Root"}"#
            case partialURL:
                body = #"{"$jason":{"head":{"templates":{"body":{"sections":[{"items":[{"+":"leaf.json"}]}]}}}}}"#
            case leafURL:
                body = #"{"type":"label","text":"Nested relative"}"#
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: rootURL)
        let template = try XCTUnwrap(loaded.document.jason.head?.templates?["body"]?.dictionary)
        let sections = try XCTUnwrap(template["sections"]?.array)
        let firstItem = try XCTUnwrap(sections.first?.dictionary?["items"]?.array?.first?.dictionary)

        XCTAssertEqual(firstItem["text"]?.string, "Nested relative")
        XCTAssertTrue(requested.contains(leafURL))
    }

    func testLoadResolvingIncludesWithMetadataFetchesLoopTemplateOnceBeforeRender() async throws {
        let base = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed"
        let fixtures: [String: String] = [
            "\(base)/index.json": try loadFixtureString("Jasonpedia/webcontainer/feed/index.json"),
            "\(base)/db.json": try loadFixtureString("Jasonpedia/webcontainer/feed/db.json"),
            "\(base)/item.json": try loadFixtureString("Jasonpedia/webcontainer/feed/item.json"),
            "\(base)/special_item.json": try loadFixtureString("Jasonpedia/webcontainer/feed/special_item.json"),
            "\(base)/animated_item.json": try loadFixtureString("Jasonpedia/webcontainer/feed/animated_item.json")
        ]
        var requestCounts: [String: Int] = [:]
        StubURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            requestCounts[url, default: 0] += 1
            let body = try XCTUnwrap(fixtures[url], "Unexpected request: \(url)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: URL(string: "\(base)/index.json")!)
        let data = loaded.document.jason.head?.data?.compactMapValues { $0.unwrapped } ?? [:]
        let template = try XCTUnwrap(loaded.document.jason.head?.templates?["body"]?.unwrapped)
        let rendered = TemplateEngine.render(template, context: data)
        let renderedData = try JSONSerialization.data(withJSONObject: rendered)
        let body = try JSONDecoder().decode(JasonBody.self, from: renderedData)

        let items = try XCTUnwrap(data["items"] as? [Any])
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(body.sections?.first?.items?.count, 5)
        XCTAssertEqual(body.sections?.first?.items?.first?.components?.first?.url, "https://pbs.twimg.com/profile_images/557061751150112768/eMwi4Xz2.jpeg")
        XCTAssertEqual(requestCounts["\(base)/item.json"], 1)
    }

    func testLoadResolvingIncludesWithMetadataLetsDocumentReferencesSeeMergedOverlay() async throws {
        let rootURL = URL(string: "https://example.com/webcontainer/iframe.json")!
        let templateURL = URL(string: "https://example.com/webcontainer/template.json")!
        StubURLProtocol.requestHandler = { request in
            let body: String
            switch request.url {
            case rootURL:
                body = ##"{"+":"template.json","title":"Overlay Title","theme":"#123456","html":"<h1>Overlay HTML</h1>","action":{"type":"$default"}}"##
            case templateURL:
                body = #"{"$jason":{"head":{"templates":{"body":{"header":{"title":{"+":"$document.title"},"style":{"background":{"+":"$document.theme"}}},"style":{"background":{"type":"html","text":{"+":"$document.html"},"action":{"+":"$document.action"}}}}}}}}"#
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: rootURL)
        let bodyTemplate = try XCTUnwrap(loaded.document.jason.head?.templates?["body"]?.dictionary)
        let header = try XCTUnwrap(bodyTemplate["header"]?.dictionary)
        let style = try XCTUnwrap(bodyTemplate["style"]?.dictionary)
        let background = try XCTUnwrap(style["background"]?.dictionary)

        XCTAssertEqual(header["title"]?.string, "Overlay Title")
        XCTAssertEqual(header["style"]?.dictionary?["background"]?.string, "#123456")
        XCTAssertEqual(background["text"]?.string, "<h1>Overlay HTML</h1>")
        XCTAssertEqual(background["action"]?.dictionary?["type"]?.string, "$default")
    }

    func testLoadResolvingIncludesWithMetadataFailsSoftForLegacyAtDataMixin() async throws {
        let rootURL = URL(string: "https://example.com/mixin.json")!
        StubURLProtocol.requestHandler = { request in
            guard request.url == rootURL else { throw URLError(.cannotFindHost) }
            let body = #"{"$jason":{"head":{"data":{"@":"missing.json","title":"Inline"},"templates":{"body":{"sections":[{"items":[{"type":"label","text":"{{title}}"}]}]}}}}}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: rootURL)

        XCTAssertEqual(loaded.document.jason.head?.data?["title"]?.string, "Inline")
        XCTAssertEqual(loaded.document.jason.head?.data?["@"]?.string, "missing.json")
    }

    func testLoadResolvingIncludesWithMetadataUsesLoadedDocumentRootForSelectedPathDocumentReferences() async throws {
        let rootURL = URL(string: "https://example.com/root.json")!
        let partialURL = URL(string: "https://example.com/partial.json")!
        StubURLProtocol.requestHandler = { request in
            let body: String
            switch request.url {
            case rootURL:
                body = #"{"$jason":{"head":{"templates":{"body":{"sections":[{"items":[{"+":"item@partial.json"}]}]}}}}}"#
            case partialURL:
                body = #"{"title":"Partial Title","item":{"type":"label","text":{"+":"$document.title"}}}"#
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: rootURL)
        let template = try XCTUnwrap(loaded.document.jason.head?.templates?["body"]?.dictionary)
        let sections = try XCTUnwrap(template["sections"]?.array)
        let firstItem = try XCTUnwrap(sections.first?.dictionary?["items"]?.array?.first?.dictionary)

        XCTAssertEqual(firstItem["text"]?.string, "Partial Title")
    }

    func testLoadResolvingIncludesWithMetadataDoesNotTreatAtInsideURLAsPathSeparator() async throws {
        let rootURL = URL(string: "https://example.com/root.json")!
        let remoteURL = URL(string: "https://example.com/remote.json?email=a@b.com")!
        var requestedRemote = false
        StubURLProtocol.requestHandler = { request in
            let body: String
            switch request.url {
            case rootURL:
                body = #"{"+":"https://example.com/remote.json?email=a@b.com"}"#
            case remoteURL:
                requestedRemote = true
                body = #"{"$jason":{"head":{"title":"Remote"},"body":{"sections":[]}}}"#
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let loaded = try await loader.loadResolvingIncludesWithMetadata(from: rootURL)

        XCTAssertTrue(requestedRemote)
        XCTAssertEqual(loaded.document.jason.head?.title, "Remote")
    }

    func testLoadResolvingIncludesWithMetadataRejectsNestedIncludeCycle() async throws {
        let a = URL(string: "https://example.com/a.json")!
        let b = URL(string: "https://example.com/b.json")!
        StubURLProtocol.requestHandler = { request in
            let body: String
            switch request.url {
            case a: body = #"{"+":"b.json"}"#
            case b: body = #"{"+":"a.json"}"#
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                body = "{}"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        do {
            _ = try await loader.loadResolvingIncludesWithMetadata(from: a)
            XCTFail("Expected include cycle error")
        } catch DocumentLoader.DocumentError.includeCycle {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Footer / tabs

    func testDecodeDocumentWithFooterTabs() throws {
        let json = """
        {
            "$jason": {
                "head": {"title": "Tabs"},
                "body": {
                    "sections": [],
                    "footer": {
                        "tabs": {
                            "items": [
                                {"type": "label", "text": "Home"},
                                {"type": "label", "text": "Settings"}
                            ]
                        }
                    }
                }
            }
        }
        """
        let doc = try loader.decode(Data(json.utf8))
        XCTAssertEqual(doc.jason.body?.footer?.tabs?.items?.count, 2)
        XCTAssertEqual(doc.jason.body?.footer?.tabs?.items?.first?.text, "Home")
    }
}
