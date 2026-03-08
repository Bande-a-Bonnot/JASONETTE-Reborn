import XCTest
@testable import Jasonette

@MainActor
final class StateManagerBindingTests: XCTestCase {
    private let suiteName = "StateManagerBindingTests"

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStateManager() -> StateManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StateManager(defaults: defaults)
    }

    // MARK: - String binding

    func testStringBindingReadsFromLocalState() {
        let sm = makeStateManager()
        sm.set(["name": "Alice"])
        let binding = sm.binding(forKey: "name", default: "")
        XCTAssertEqual(binding.wrappedValue, "Alice")
    }

    func testStringBindingWritesToLocalState() {
        let sm = makeStateManager()
        let binding = sm.binding(forKey: "name", default: "")
        binding.wrappedValue = "Bob"
        XCTAssertEqual(sm.get()["name"] as? String, "Bob")
    }

    // MARK: - Double binding

    func testDoubleBindingReadsIntAsDouble() {
        let sm = makeStateManager()
        sm.set(["count": 42])
        let binding = sm.binding(forKey: "count", default: 0.0)
        XCTAssertEqual(binding.wrappedValue, 42.0)
    }

    func testDoubleBindingReturnsDefaultWhenMissing() {
        let sm = makeStateManager()
        let binding = sm.binding(forKey: "missing", default: 3.14)
        XCTAssertEqual(binding.wrappedValue, 3.14)
    }

    // MARK: - Bool binding

    func testBoolBindingReadsAndWrites() {
        let sm = makeStateManager()
        sm.set(["enabled": true])
        let binding = sm.binding(forKey: "enabled", default: false)
        XCTAssertEqual(binding.wrappedValue, true)
        binding.wrappedValue = false
        XCTAssertEqual(sm.get()["enabled"] as? Bool, false)
    }

    // MARK: - UserDefaults isolation

    func testUserDefaultsIsolation() {
        let suite1 = "StateManagerBindingTests.suite1"
        let suite2 = "StateManagerBindingTests.suite2"
        let defaults1 = UserDefaults(suiteName: suite1)!
        let defaults2 = UserDefaults(suiteName: suite2)!
        defaults1.removePersistentDomain(forName: suite1)
        defaults2.removePersistentDomain(forName: suite2)

        let sm1 = StateManager(defaults: defaults1)
        let sm2 = StateManager(defaults: defaults2)

        sm1.cacheSet(["token": "secret1"])
        sm2.cacheSet(["token": "secret2"])

        XCTAssertEqual(sm1.cacheGet()["token"] as? String, "secret1")
        XCTAssertEqual(sm2.cacheGet()["token"] as? String, "secret2")

        // Cleanup
        defaults1.removePersistentDomain(forName: suite1)
        defaults2.removePersistentDomain(forName: suite2)
    }
}
