---
title: "iOS test isolation patterns: UserDefaults, URLSession, and timer testing"
date: 2026-03-08
category: test-failures
tags: [swift, xctest, test-isolation, userdefaults, urlsession, urlprotocol, timers, dependency-injection, async-await]
module: iOS Tests
symptom: "Tests pass individually but fail when run together; timer tests are flaky; network tests hit real endpoints"
root_cause: "Shared mutable state (UserDefaults.standard, URLSession.shared, global timers) bleeds between tests"
severity: test-reliability
---

# iOS Test Isolation Patterns

## 1. UserDefaults Isolation via Suite Name

Never use `UserDefaults.standard` in tests. Create an isolated suite per test class:

```swift
final class MyTests: XCTestCase {
    private let suiteName = "MyTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
}
```

**Key:** The production code must accept `UserDefaults` as a parameter with a default value:

```swift
public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
}
```

This is fully backward-compatible — callers that don't pass `defaults:` get `.standard` as before.

## 2. URLSession Stubbing with URLProtocol

Intercept network requests without hitting real endpoints:

```swift
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

**Setup:** Use an ephemeral session configuration so no caching interferes:

```swift
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [StubURLProtocol.self]
let session = URLSession(configuration: config)
let sut = ActionDispatcher(stateManager: stateManager, session: session)
```

**`nonisolated(unsafe)`:** Required for Swift 6 strict concurrency — `static var` on a non-Sendable class needs this annotation.

## 3. Timer Test Calibration

Timer tests are inherently timing-sensitive. Use these margins:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Timer interval | 0.1s | Minimum allowed (clamped from lower values) |
| asyncAfter delay | 0.3s | 3x the interval — enough for CI slowness |
| XCTest timeout | 1.0s | Generous failsafe; test finishes in ~0.3s normally |

```swift
func testTimerFires() async {
    let expectation = expectation(description: "timer fired")
    // Start timer with 0.1s interval
    await dispatcher.execute(timerAction)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        if self.stateManager.get()["fired"] as? Bool == true {
            expectation.fulfill()
        }
    }
    await fulfillment(of: [expectation], timeout: 1.0)
}
```

**Always invalidate timers in tearDown:**

```swift
override func tearDown() {
    dispatcher.invalidateAllTimers()
    super.tearDown()
}
```

## 4. Success Chaining vs Timer Callback Isolation

When an action has a `success` chain, `execute()` fires it immediately. To test that the *timer callback* (not the success chain) fires:

```swift
await dispatcher.execute(actionWithSuccess)
// execute() already fired success — reset the marker
stateManager.set(["marker": "reset"])

// Now wait for the timer callback to fire
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    XCTAssertEqual(self.stateManager.get()["marker"] as? Bool, true)
    expectation.fulfill()
}
```

## 5. @MainActor Test Classes

For classes that interact with UI or main-thread state, annotate the entire test class:

```swift
@MainActor
final class ActionDispatcherTests: XCTestCase {
    // All test methods are implicitly @MainActor
    func testSomething() async { ... }
}
```

## Lesson

Test isolation in iOS requires dependency injection of every external dependency: `UserDefaults`, `URLSession`, timers. Default parameter values (`= .standard`, `= .shared`) make injection backward-compatible. Timer tests need explicit margins (3x interval) and tearDown cleanup.
