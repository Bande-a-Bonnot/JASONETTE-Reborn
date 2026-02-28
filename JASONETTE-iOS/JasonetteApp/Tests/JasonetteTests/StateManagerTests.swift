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
}
