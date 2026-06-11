import XCTest
@testable import Jasonette

@MainActor
final class SecurityTests: XCTestCase {
    private var stateManager: StateManager!
    private var dispatcher: ActionDispatcher!
    private var stubSession: URLSession!
    private let suiteName = "SecurityTests"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        stateManager = StateManager(defaults: defaults)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        stubSession = URLSession(configuration: config)

        dispatcher = ActionDispatcher(stateManager: stateManager, session: stubSession)
    }

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func decodeAction(_ json: [String: Any]) -> JasonAction {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonAction.self, from: data)
    }

    private func setStubOK() {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
    }

    // MARK: - Blocked URL schemes

    func testRejectsFileURL() async {
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "file:///etc/passwd"],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    func testRejectsFTPURL() async {
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "ftp://example.com/file"],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    func testRejectsJavascriptURL() async {
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "javascript:alert(1)"],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    func testAllowsHTTPS() async {
        setStubOK()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/api"],
            "success": ["type": "$set", "options": ["success": true]],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertNil(stateManager.get()["error_fired"])
    }

    // MARK: - Blocked headers

    func testStripsAuthorizationHeader() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": [
                "url": "https://example.com/api",
                "headers": ["Authorization": "Bearer secret"]
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testStripsCookieHeader() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": [
                "url": "https://example.com/api",
                "headers": ["Cookie": "session=abc"]
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testStripsHostHeader() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Host"))
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": [
                "url": "https://example.com/api",
                "headers": ["Host": "evil.com"]
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testStripsProxyAuthorizationHeader() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Proxy-Authorization"))
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": [
                "url": "https://example.com/api",
                "headers": ["Proxy-Authorization": "Basic abc"]
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testAllowsCustomHeaders() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "hello")
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": [
                "url": "https://example.com/api",
                "headers": ["X-Custom": "hello"]
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Expression security

    func testExpressionBlocksProtoAccess() {
        let result = ExpressionEvaluator.evaluate("obj.__proto__", context: [
            "obj": ["key": "value"]
        ])
        XCTAssertNil(result)
    }

    func testExpressionBlocksConstructorAccess() {
        let result = ExpressionEvaluator.evaluate("obj.constructor", context: [
            "obj": ["key": "value"]
        ])
        XCTAssertNil(result)
    }

    // MARK: - Computed member blocklist bypass

    func testComputedMemberBlocksProtoAccess() {
        // obj["__proto__"] should be blocked the same as obj.__proto__
        let result = ExpressionEvaluator.evaluate("obj['__proto__']", context: [
            "obj": ["key": "value"]
        ])
        XCTAssertNil(result)
    }

    func testComputedMemberBlocksConstructorAccess() {
        let result = ExpressionEvaluator.evaluate("obj['constructor']", context: [
            "obj": ["key": "value"]
        ])
        XCTAssertNil(result)
    }

    func testComputedMemberBlocksPrototypeAccess() {
        let result = ExpressionEvaluator.evaluate("obj['prototype']", context: [
            "obj": ["key": "value"]
        ])
        XCTAssertNil(result)
    }

    func testComputedMemberAllowsNormalStringKey() {
        let result = ExpressionEvaluator.evaluate("obj['name']", context: [
            "obj": ["name": "Alice"]
        ])
        XCTAssertEqual(result as? String, "Alice")
    }

    // MARK: - Network response namespacing

    func testNetworkResponseNamespacedUnderResponse() async {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"field":"value"}"#.utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/api"]
        ])
        await dispatcher.execute(action)
        // Response body must be nested under "$response", not merged at the top level
        let responseDict = stateManager.get()["$response"] as? [String: Any]
        XCTAssertEqual(responseDict?["field"] as? String, "value")
        XCTAssertNil(stateManager.get()["field"], "Response keys must not be hoisted to the top-level state")
    }

    func testNetworkResponseCannotOverwriteJasonNamespace() async {
        stateManager.set(["$jason": ["safe": true]])
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"$jason":"injected","field":"value"}"#.utf8))
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/api"]
        ])

        await dispatcher.execute(action)

        let existingJason = stateManager.get()["$jason"] as? [String: Any]
        XCTAssertEqual(existingJason?["safe"] as? Bool, true)
        let responseDict = stateManager.get()["$response"] as? [String: Any]
        XCTAssertEqual(responseDict?["$jason"] as? String, "injected")
        XCTAssertEqual(responseDict?["field"] as? String, "value")
    }

    // MARK: - Edge cases

    func testEmptyURLReturnsError() async {
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": ""],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    func testMalformedURLReturnsError() async {
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "ht tp://bad url"],
            "error": ["type": "$set", "options": ["error_fired": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }
}
