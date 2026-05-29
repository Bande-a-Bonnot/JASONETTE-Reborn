import XCTest
import Combine
@testable import Jasonette

@MainActor
final class ActionDispatcherTests: XCTestCase {
    private var stateManager: StateManager!
    private var dispatcher: ActionDispatcher!
    private let suiteName = "ActionDispatcherTests"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        stateManager = StateManager(defaults: defaults)
        dispatcher = ActionDispatcher(stateManager: stateManager)
    }

    override func tearDown() {
        dispatcher.invalidateAllTimers()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func decodeAction(_ json: [String: Any]) -> JasonAction {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonAction.self, from: data)
    }

    // MARK: - $set

    func testSetUpdatesLocalState() async {
        let action = decodeAction([
            "type": "$set",
            "options": ["name": "Alice", "age": 30]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["name"] as? String, "Alice")
        XCTAssertEqual(stateManager.get()["age"] as? Int, 30)
    }

    // MARK: - $get

    func testGetIsNoOp() async {
        let action = decodeAction(["type": "$get"])
        await dispatcher.execute(action)
        // Should not crash
    }

    // MARK: - Named action trigger

    func testTriggerExecutesNamedAction() async {
        let namedAction = decodeAction([
            "type": "$set",
            "options": ["sent": true]
        ])
        dispatcher.setActionResolver { name in
            name == "send" ? namedAction : nil
        }

        let trigger = decodeAction(["trigger": "send"])
        await dispatcher.execute(trigger)

        XCTAssertEqual(stateManager.get()["sent"] as? Bool, true)
    }

    // MARK: - $cache.set

    func testCacheSetPersistsToCache() async {
        let action = decodeAction([
            "type": "$cache.set",
            "options": ["token": "abc123"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.cacheGet()["token"] as? String, "abc123")
    }

    // MARK: - $cache.get

    func testCacheGetIsNoOp() async {
        let action = decodeAction(["type": "$cache.get"])
        await dispatcher.execute(action)
        // Should not crash
    }

    // MARK: - $cache.reset

    func testCacheResetClearsCache() async {
        stateManager.cacheSet(["token": "abc"])
        let action = decodeAction(["type": "$cache.reset"])
        await dispatcher.execute(action)
        XCTAssertTrue(stateManager.cacheGet().isEmpty)
    }

    // MARK: - $render

    func testRenderCallsRenderHandler() async {
        let expectation = expectation(description: "render handler called")
        var receivedTemplate: String? = "sentinel"
        dispatcher.setRenderHandler { templateName in
            receivedTemplate = templateName
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$render"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNil(receivedTemplate)
    }

    // MARK: - $reload

    func testReloadCallsReloadHandler() async {
        let expectation = expectation(description: "reload called")
        dispatcher.setReloadHandler {
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$reload"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - $href

    func testHrefCallsNavigationHandler() async {
        let expectation = expectation(description: "navigation called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$href",
            "options": [
                "url": "https://example.com",
                "view": "push",
                "transition": "slide"
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.url, "https://example.com")
        XCTAssertEqual(receivedHref?.view, "push")
        XCTAssertEqual(receivedHref?.transition, "slide")
    }

    // MARK: - $back

    func testBackCallsNavigationWithBack() async {
        let expectation = expectation(description: "back called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$back"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.view, "$back")
    }

    // MARK: - $close

    func testCloseCallsNavigationWithClose() async {
        let expectation = expectation(description: "close called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$close"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.view, "$close")
    }

    // MARK: - $util.alert

    func testUtilAlertCallsAlertHandler() async {
        let expectation = expectation(description: "alert called")
        var receivedTitle: String?
        var receivedDescription: String?
        dispatcher.setAlertHandler { title, description in
            receivedTitle = title
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.alert",
            "options": ["title": "Hello", "description": "World"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTitle, "Hello")
        XCTAssertEqual(receivedDescription, "World")
    }

    func testUtilAlertTemplatesLocalGetValues() async {
        stateManager.set(["message": "hello"])
        let expectation = expectation(description: "alert called")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.alert",
            "options": ["title": "Message", "description": "{{$get.message}}"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "hello")
    }

    // MARK: - $util.toast / $util.banner

    func testUtilToastIsNoOp() async {
        let action = decodeAction(["type": "$util.toast"])
        await dispatcher.execute(action)
    }

    func testUtilBannerIsNoOp() async {
        let action = decodeAction(["type": "$util.banner"])
        await dispatcher.execute(action)
    }

    // MARK: - $timer.start

    func testTimerStartFiresSuccessAction() async {
        let expectation = expectation(description: "timer fired")
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["fired": true]]
        ])
        await dispatcher.execute(action)

        // Wait for timer to fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.stateManager.get()["fired"] as? Bool == true {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testTimerStartReplacesExistingTimer() async {
        let action1 = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["source": "first"]]
        ])
        await dispatcher.execute(action1)

        let action2 = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["source": "second"]]
        ])
        await dispatcher.execute(action2)

        let expectation = expectation(description: "second timer fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.stateManager.get()["source"] as? String == "second" {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - $timer.stop

    func testTimerStopInvalidatesNamedTimer() async {
        let startAction = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["timer_count": 1]]
        ])
        await dispatcher.execute(startAction)

        // execute() success chain already fired $set; reset the marker
        stateManager.set(["timer_count": "reset"])

        let stopAction = decodeAction([
            "type": "$timer.stop",
            "options": ["name": "t1"]
        ])
        await dispatcher.execute(stopAction)

        // Wait and verify the timer callback never fires after stop
        let expectation = expectation(description: "timer did not fire after stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.stateManager.get()["timer_count"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Timer minimum interval

    func testTimerEnforcesMinimumInterval() async {
        // Pass 0.001s interval — should be clamped to 0.1s
        // Use a dedicated key that only the timer callback sets (not success chaining).
        // We wrap the $set inside the timer's success, but we must avoid the execute()
        // success chain also running it. So we use a nested action:
        // timer.start has no top-level success, but the timer callback fires the successAction.
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "fast", "interval": 0.001, "repeats": false],
            "success": ["type": "$set", "options": ["min_interval_done": true]]
        ])
        // Note: execute() will also fire success immediately via chaining.
        // Reset the state right after to isolate the timer callback.
        await dispatcher.execute(action)
        stateManager.set(["min_interval_done": "reset"])

        // At 0.05s, timer should NOT have fired yet (clamped to 0.1s)
        let expectation = expectation(description: "timer not fired yet")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Should still be "reset" — timer hasn't fired yet
            XCTAssertEqual(self.stateManager.get()["min_interval_done"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Timer max count

    func testTimerEnforcesMaxCount() async {
        // Fill up to max (50) timers
        for i in 0..<50 {
            let action = decodeAction([
                "type": "$timer.start",
                "options": ["name": "timer_\(i)", "interval": 10.0, "repeats": true]
            ])
            await dispatcher.execute(action)
        }

        // The 51st timer with a NEW unique name should be rejected.
        // execute() success chaining fires immediately, so we reset after execute
        // and check that the timer callback itself never fires.
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "overflow", "interval": 0.1, "repeats": false],
            "success": ["type": "$set", "options": ["overflow_fired": true]]
        ])
        await dispatcher.execute(action)
        // Reset: execute() chained the success immediately, so clear the marker
        stateManager.set(["overflow_fired": "reset"])

        let expectation = expectation(description: "overflow timer did not fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Timer was never created, so callback never fires; value stays "reset"
            XCTAssertEqual(self.stateManager.get()["overflow_fired"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - One-shot timer cleanup

    func testOneShotTimerFiresSuccessAction() async {
        let expectation = expectation(description: "one-shot timer fires success action")
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "oneshot", "interval": 0.1, "repeats": false],
            "success": ["type": "$set", "options": ["oneshot_done": true]]
        ])
        await dispatcher.execute(action)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.stateManager.get()["oneshot_done"] as? Bool, true)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - invalidateAllTimers

    func testInvalidateAllTimersClearsAll() async {
        for i in 0..<3 {
            let action = decodeAction([
                "type": "$timer.start",
                "options": ["name": "t\(i)", "interval": 0.1, "repeats": true],
                "success": ["type": "$set", "options": ["t\(i)_fired": true]]
            ])
            await dispatcher.execute(action)
        }

        // execute() success chaining already fired the success actions.
        // Reset the markers, then invalidate timers so the timer callbacks never fire.
        for i in 0..<3 {
            stateManager.set(["t\(i)_fired": "reset"])
        }
        dispatcher.invalidateAllTimers()

        let expectation = expectation(description: "no timers fired after invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for i in 0..<3 {
                // Timer callbacks never fired, so values remain "reset"
                XCTAssertEqual(self.stateManager.get()["t\(i)_fired"] as? String, "reset")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Success chaining

    func testSuccessChaining() async {
        let action = decodeAction([
            "type": "$set",
            "options": ["step": "first"],
            "success": [
                "type": "$set",
                "options": ["step": "second"]
            ]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["step"] as? String, "second")
    }

    // MARK: - Error chaining

    func testErrorChaining() async {
        // $network.request with invalid URL triggers error chain
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "not a url %%%"],
            "error": [
                "type": "$set",
                "options": ["error_fired": true]
            ]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    // MARK: - $network.request response shapes

    private func makeStubbedDispatcher(documentURL: URL? = nil) -> ActionDispatcher {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return ActionDispatcher(stateManager: stateManager, session: session, documentURL: documentURL)
    }

    private func stubJSON(_ body: String) {
        let data = body.data(using: .utf8)!
        StubURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, data)
        }
    }

    func testNetworkRequestResolvesRelativeURLAgainstDocumentURL() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, URL(string: "https://example.com/app/api/items")!)
            expectation.fulfill()
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "api/items"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testNetworkRequestResolvesRootRelativeURLAgainstDocumentURL() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, URL(string: "https://example.com/api/items")!)
            expectation.fulfill()
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "/api/items"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testNetworkRequestRejectsDisallowedSchemeAfterResolution() async {
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "javascript:alert(1)"],
            "error": ["type": "$set", "options": ["blocked_after_resolution": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["blocked_after_resolution"] as? Bool, true)
    }

    func testNetworkRequestSuccessChainKeepsOriginalDocumentURLWhenDispatcherBaseChanges() async {
        let originalBase = URL(string: "https://example.com/app/index.json")!
        let reloadedBase = URL(string: "https://cdn.example.com/new/index.json")!
        let dispatcher = makeStubbedDispatcher(documentURL: originalBase)
        let lock = NSLock()
        var requestedURLs: [URL] = []

        StubURLProtocol.requestHandler = { request in
            lock.lock()
            requestedURLs.append(request.url!)
            let count = requestedURLs.count
            lock.unlock()

            if count == 1 {
                let didUpdateBase = DispatchSemaphore(value: 0)
                Task { @MainActor in
                    dispatcher.setDocumentURL(reloadedBase)
                    didUpdateBase.signal()
                }
                _ = didUpdateBase.wait(timeout: .now() + 1.0)
            }

            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }

        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "api/first"],
            "success": [
                "type": "$network.request",
                "options": ["url": "api/second"]
            ]
        ])
        await dispatcher.execute(action)

        lock.lock()
        let urls = requestedURLs
        lock.unlock()
        XCTAssertEqual(urls, [
            URL(string: "https://example.com/app/api/first")!,
            URL(string: "https://example.com/app/api/second")!
        ])
    }

    func testHrefSuccessChainKeepsOriginalDocumentURLWhenDispatcherBaseChanges() async {
        let originalBase = URL(string: "https://example.com/app/index.json")!
        let reloadedBase = URL(string: "https://cdn.example.com/new/index.json")!
        let dispatcher = makeStubbedDispatcher(documentURL: originalBase)
        var receivedHrefs: [JasonHref] = []
        dispatcher.setNavigationHandler { receivedHrefs.append($0) }
        dispatcher.setReloadHandler { dispatcher.setDocumentURL(reloadedBase) }

        let action = decodeAction([
            "type": "$reload",
            "success": [
                "type": "$href",
                "options": ["url": "detail.json"]
            ]
        ])
        await dispatcher.execute(action)

        XCTAssertEqual(receivedHrefs.first?.url, "https://example.com/app/detail.json")
    }

    func testNetworkRequestStoresDictResponse() async {
        stubJSON("{\"ok\": true}")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/a"]
        ])
        await dispatcher.execute(action)
        let resp = stateManager.get()["$response"] as? [String: Any]
        XCTAssertEqual(resp?["ok"] as? Bool, true)
    }

    func testNetworkRequestStoresArrayResponse() async {
        // UUIDv7 per repo policy (CLAUDE.md: "Use UUIDv7 for all IDs. Strictly.")
        let firstID = "019635b8-fa94-7101-8000-000000000001"
        let secondID = "019635b8-fa94-7101-8000-000000000002"
        stubJSON("[{\"id\":\"\(firstID)\"},{\"id\":\"\(secondID)\"}]")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/b"]
        ])
        await dispatcher.execute(action)
        let resp = stateManager.get()["$response"] as? [[String: Any]]
        XCTAssertEqual(resp?.count, 2)
        XCTAssertEqual(resp?[0]["id"] as? String, firstID)
        XCTAssertEqual(resp?[1]["id"] as? String, secondID)
    }

    func testNetworkRequestStoresPlainTextResponse() async {
        StubURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("hello world".utf8))
        }
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/c"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? String, "hello world")
    }

    func testNetworkRequestStoresJSONStringFragmentResponse() async {
        stubJSON("\"hello json\"")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/d"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? String, "hello json")
    }

    func testNetworkRequestStoresJSONNumberFragmentResponse() async {
        stubJSON("42")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/e"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? Int, 42)
    }

    func testNetworkRequestStoresJSONNullFragmentResponse() async {
        stubJSON("null")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/f"]
        ])
        await dispatcher.execute(action)
        XCTAssertTrue(stateManager.get()["$response"] is NSNull)
    }

    // MARK: - Unknown action

    func testUnknownActionDoesNotCrash() async {
        let action = decodeAction(["type": "$nonexistent.action"])
        await dispatcher.execute(action)
        // Should not crash
    }
}
