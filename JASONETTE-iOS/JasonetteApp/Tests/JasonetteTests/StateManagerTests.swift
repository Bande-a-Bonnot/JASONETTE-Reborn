import XCTest
@testable import Jasonette

@MainActor
final class StateManagerTests: XCTestCase {
    func testSetAndGet() {
        let sm = StateManager()
        sm.set(["name": "Alice", "age": 30])
        let state = sm.get()
        XCTAssertEqual(state["name"] as? String, "Alice")
        XCTAssertEqual(state["age"] as? Int, 30)
    }

    func testSetOverwrites() {
        let sm = StateManager()
        sm.set(["key": "old"])
        sm.set(["key": "new"])
        XCTAssertEqual(sm.get()["key"] as? String, "new")
    }

    func testCacheSetAndGet() {
        let sm = StateManager()
        sm.cacheSet(["token": "abc123"])
        XCTAssertEqual(sm.cacheGet()["token"] as? String, "abc123")
    }

    func testCacheReset() {
        let sm = StateManager()
        sm.cacheSet(["token": "abc"])
        sm.cacheReset()
        XCTAssertTrue(sm.cacheGet().isEmpty)
    }

    func testFlush() {
        let sm = StateManager()
        sm.set(["key": "value"])
        sm.cacheSet(["token": "abc"])
        sm.flush()
        XCTAssertTrue(sm.get().isEmpty)
        XCTAssertTrue(sm.cacheGet().isEmpty)
    }

    func testLocalStateSeparateFromCache() {
        let sm = StateManager()
        sm.set(["local": true])
        sm.cacheSet(["cached": true])
        XCTAssertNil(sm.get()["cached"])
        XCTAssertNil(sm.cacheGet()["local"])
    }

    // MARK: - cacheSet poison prevention

    func testCacheSetRejectsNonSerializableValue() {
        let sm = StateManager()
        var violations: [String] = []
        sm._cacheSetFailureHandler = { violations.append($0) }

        sm.cacheSet(["good": "value"])
        // NSObject is not JSON-serializable — must be rejected
        sm.cacheSet(["bad": NSObject()])

        XCTAssertEqual(violations.count, 1, "Expected exactly one violation")
        XCTAssertEqual(sm.cacheGet()["good"] as? String, "value")
        XCTAssertNil(sm.cacheGet()["bad"])
    }

    func testCacheSetSubsequentWriteSucceedsAfterRejection() {
        let sm = StateManager()
        var violations: [String] = []
        sm._cacheSetFailureHandler = { violations.append($0) }

        sm.cacheSet(["a": "first"])
        // Poison attempt — dropped
        sm.cacheSet(["bad": NSObject()])
        // Valid write must still succeed (cache not poisoned)
        sm.cacheSet(["b": "second"])

        XCTAssertEqual(violations.count, 1, "Exactly one rejection expected")
        XCTAssertEqual(sm.cacheGet()["a"] as? String, "first")
        XCTAssertEqual(sm.cacheGet()["b"] as? String, "second")
        XCTAssertNil(sm.cacheGet()["bad"])
    }
}
