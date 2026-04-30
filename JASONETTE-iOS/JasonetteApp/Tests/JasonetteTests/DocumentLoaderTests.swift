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
