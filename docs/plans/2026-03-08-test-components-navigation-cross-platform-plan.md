---
title: "Comprehensive Component, Navigation, and Cross-Platform Tests"
type: feat
date: 2026-03-08
deepened: 2026-03-08
---

## Enhancement Summary

**Deepened on:** 2026-03-08
**Research agents used:** XCTest async patterns, Kotlin JUnit4 patterns, security sentinel, performance oracle, simplicity reviewer, learnings researcher

### Key Improvements

1. **Scope cut from ~80 to ~40 tests** — focus iOS first, Android parity second, Web deferred entirely (legacy gulp 3.x codebase not worth vitest infrastructure for 5 tests)
2. **Inject dependencies for testability** — URLSession, UserDefaults(suiteName:), timer intervals; avoids global shared state and flaky CI
3. **Test data layer, not SwiftUI rendering** — ComponentRegistry dispatch + StateManager bindings, not opaque View body inspection
4. **Cross-platform consistency = iOS vs Android only** — Web uses ST.transform (different template contract), not comparable
5. **Security boundary tests prioritized** — blocked headers, blocked URL schemes, blocked expression properties are highest-value tests
6. **Timer tests use 0.01s intervals** — not 0.15s; keeps entire test suite under 2 seconds
7. **Learnings incorporated** — mixed Int/Double arithmetic for cross-platform parity (kotlin-intordouble-operator-dispatch.md), mixed JSON types for Android action options (kotlin-json-safe-cast.md)

### Refactoring Required Before Tests

1. **`StateManager.init(defaults:)`** — accept optional `UserDefaults` parameter, default to `.standard`. Tests pass `UserDefaults(suiteName: "test-\(UUID())")` for isolation.
2. **`ActionDispatcher.init(stateManager:session:)`** — accept optional `URLSession` parameter, default to `.shared`. Tests pass ephemeral session with `StubURLProtocol`.
3. **Android `resolveStyle`** — change from `private` to `internal` for testability.

# Comprehensive Component, Navigation, and Cross-Platform Tests

## Problem Statement

98 iOS tests and 55 Android tests pass, but coverage is limited to pure-logic layers (template engine, expression evaluator, document decoding, color parsing, style merging, state manager). Zero tests exist for:

- Component dispatch (JSON type string → correct component with correct params)
- Navigation transitions (push, modal, safari, openURL, $back, $close)
- Action dispatcher ($set, $href, $timer, $util.alert, $network.request)
- ViewModel lifecycle (load, render fallback, pull-to-refresh)
- Cross-platform consistency (same JSON → same output on iOS and Android)
- Security boundaries (blocked headers, blocked URL schemes, blocked expression properties)

The "Tests Pass But Feature Is Broken" learning (docs/solutions/) warns that unit tests on source code don't guarantee the shipped artifact works. This plan adds both unit tests AND integration-level pipeline tests.

## Proposed Solution

Add ~80 new tests across 3 platforms in 4 phases:

1. **iOS unit tests** — ActionDispatcher, ViewModel, component dispatch, navigation handlers
2. **Android unit tests** — StateManager, StyleModifier, ColorParsing, ActionDispatcher
3. **Cross-platform consistency** — shared JSON fixtures, identical expected output
4. **Web baseline** — add vitest, test template engine independently

### Architecture Decision: Component Testing Strategy

SwiftUI views have opaque `body` types — cannot be inspected with XCTest alone. Instead of adding ViewInspector (third-party dependency), test the **data transform layer**:

- Verify `ComponentRegistry` dispatches the correct component type for each JSON `type` string
- Verify `StateManager.binding()` produces correct read/write bindings
- Verify component init params are correctly extracted from `JasonComponent`
- Leave SwiftUI rendering validation to manual QA / future XCUITest

### Architecture Decision: Test Isolation

- iOS `StateManager` → inject `UserDefaults(suiteName: "test-\(UUID())")` to isolate cache; clean up in `tearDown` with `suiteName.removePersistentDomain`
- iOS `ActionDispatcher` → inject `URLSession` with ephemeral config + `StubURLProtocol` (not `URLProtocol.registerClass` on `.shared` which is global mutable state that leaks between tests)
- Android `StateManager` → test with `context = null` (local-only, cache ops no-op)
- Timers → use `0.01s` intervals with `XCTestExpectation(timeout: 0.1s)` — keeps timer tests under 100ms total vs 1-2s with 0.15s intervals
- All iOS test classes testing `@MainActor` types must be annotated `@MainActor`

### Architecture Decision: Cross-Platform Scope

Cross-platform consistency tests cover **iOS and Android only**. The Web renderer uses `ST.transform` (SelectTransform library) — a fundamentally different template contract from the custom `TemplateEngine` on iOS/Android. Web gets independent tests.

## Acceptance Criteria

### Phase 1: iOS Tests (~45 new tests)

#### ActionDispatcher Tests — `ActionDispatcherTests.swift`

- [x] `$set` updates StateManager local state
- [x] `$get` is a no-op (does not crash)
- [x] `$cache.set` persists to cache
- [x] `$cache.get` is a no-op (does not crash)
- [x] `$cache.reset` clears cache
- [x] `$render` triggers `objectWillChange`
- [x] `$reload` calls reload handler
- [x] `$href` calls navigation handler with correct JasonHref
- [x] `$back` calls navigation handler with view="$back"
- [x] `$close` calls navigation handler with view="$close"
- [x] `$util.alert` calls alert handler with title and description
- [x] `$util.toast` is a no-op (does not crash)
- [x] `$util.banner` is a no-op (does not crash)
- [x] `$timer.start` fires success action after interval (use 0.01s interval, 0.1s expectation timeout)
- [x] `$timer.start` replaces existing timer with same name
- [x] `$timer.stop` invalidates named timer
- [x] `$timer.start` enforces minimum interval (0.1s) — pass 0.001s, verify clamped
- [x] `$timer.start` enforces max timer count (50)
- [x] One-shot timer cleans up dict entry after firing
- [x] `invalidateAllTimers()` clears all timers
- [x] Action success chaining — success action fires after parent
- [x] Action error chaining — error action fires on failure
- [x] Unknown action type does not crash

#### Security Boundary Tests — `SecurityTests.swift`

- [x] `$network.request` rejects `file://` URL
- [x] `$network.request` rejects `ftp://` URL
- [x] `$network.request` rejects `javascript:` URL
- [x] `$network.request` allows `https://` URL
- [x] `$network.request` strips `Authorization` header
- [x] `$network.request` strips `Cookie` header
- [x] `$network.request` strips `Host` header
- [x] `$network.request` strips `Proxy-Authorization` header
- [x] `$network.request` allows custom non-blocked headers (e.g. `X-Custom`)
- [x] Expression evaluator blocks `__proto__` access (already tested — verify Android parity)
- [x] Expression evaluator blocks `constructor` access (already tested — verify Android parity)
- [x] `$network.request` with empty URL string returns error
- [x] `$network.request` with malformed URL returns error

#### ViewModel Tests — `ViewModelTests.swift`

- [x] `loadIfNeeded()` transitions from .idle → .loading → .loaded
- [x] `loadIfNeeded()` does not reload when already .loaded
- [x] `render()` falls back to raw document on serialization failure
- [x] `handleHref()` posts jasonetteNavigate notification with correct userInfo
- [x] `handleHref()` with view="$back" posts back=true
- [x] `handleHref()` with view="$close" posts close=true
- [x] `handlePull()` executes $pull action then re-renders
- [x] `handlePull()` calls load() when no $pull action defined
- [x] `$load` lifecycle action fires after initial load

#### Component Dispatch Tests — `ComponentDispatchTests.swift`

- [x] type "label" → dispatches with text param
- [x] type "image" → dispatches with url param
- [x] type "button" → dispatches with text and url params
- [x] type "textfield" → dispatches with name, placeholder, keyboard, initialValue
- [x] type "textarea" → dispatches with name, placeholder
- [x] type "slider" → dispatches with name, value
- [x] type "switch" → dispatches with name, isOn
- [x] type "space" → dispatches with height from style
- [x] type "map" → dispatches MapStubComponent
- [x] unknown type → renders "[Unknown: foo]"

#### StateManager Binding Tests — `StateManagerBindingTests.swift`

- [x] String binding reads from local state
- [x] String binding writes to local state
- [x] Double binding reads Int as Double (no truncation)
- [x] Double binding returns default when key missing
- [x] Bool binding reads and writes correctly
- [x] UserDefaults isolation — separate suites don't leak

### Phase 2: Android Tests (~20 new tests)

#### StateManager Tests — `StateManagerTest.kt`

- [x] `set()` stores values in local map
- [x] `get()` returns current local state
- [x] `flush()` clears local state
- [x] Local state is separate from cache (with null context, cache no-ops)

#### Style Modifier Tests — `StyleModifierTest.kt`

- [x] Single class resolves from headStyles
- [x] Multi-class merges in order (later overrides earlier)
- [x] Inline style overrides class style
- [x] Unknown class name is ignored
- [x] No class, no inline returns null

#### Color Parsing Tests — `ColorParsingTest.kt`

- [x] Hex 6-digit parses correctly
- [x] Hex 8-digit with alpha
- [x] Invalid hex returns null
- [x] `rgb(r,g,b)` parses correctly
- [x] `rgba(r,g,b,a)` parses correctly
- [x] Out of range RGB values rejected
- [x] Non-numeric alpha rejected
- [x] Case insensitive (Locale.ROOT)
- [x] Whitespace trimmed

#### ActionDispatcher Tests — `ActionDispatcherTest.kt`

- [x] `$set` updates state
- [x] `$cache.set` / `$cache.reset` work
- [x] `$render` triggers re-render callback
- [x] `$reload` triggers reload callback
- [x] `$network.request` with allowed scheme succeeds (mock)
- [x] `$network.request` rejects `file://` scheme
- [x] Unknown action does not crash

### Phase 3: Cross-Platform Consistency Tests (~10 tests)

Shared JSON fixtures in `test-fixtures/` at monorepo root.

#### Template Engine Parity

- [x] Simple interpolation: `"Hello {{name}}"` + `{name: "world"}` → `"Hello world"`
- [x] `#each` directive produces same array output
- [x] `#if` true branch renders, false branch omits
- [x] Nested access: `{{user.name}}` resolves correctly
- [x] Arithmetic expression: `{{a + b}}` evaluates identically
- [x] Ternary: `{{x > 0 ? "pos" : "neg"}}` same result

#### Expression Evaluator Parity

- [x] Integer arithmetic: `2 + 3` → `5` (same type on both platforms)
- [x] Double arithmetic: `2.5 + 1.5` → `4.0`
- [x] Mixed Int/Double: `1 + 2.5` → `3.5` (from kotlin-intordouble-operator-dispatch.md — this is where bugs live)
- [x] String concatenation: same result
- [x] Boolean logic: same truthiness rules
- [x] Member access: same nested object traversal
- [x] Expression security: `__proto__` and `constructor` blocked on both platforms

#### Document Decoding Parity

Verify same JSON document decodes to equivalent model structure on both platforms.

### Research Insight: Cross-Platform Number Handling

From `docs/solutions/kotlin-intordouble-operator-dispatch.md`: Kotlin requires explicit `intOp` and `doubleOp` for mixed-type arithmetic. Cross-platform fixtures MUST include mixed Int/Double cases (`1 + 2.5`, `3 * 0.5`) — these are the cases where iOS and Android diverge.

### Phase 4: Web Baseline — DEFERRED

**Decision:** Deferred per simplicity review. The Web codebase is 1,033 lines of gulp 3.x vanilla JS with no modules, no imports/exports, and `"test": "echo \"Error: no test specified\" && exit 1"`. Adding vitest requires: ESM transform or bundler config, jsdom setup, ST (SelectTransform) global shimming, and fighting gulp 3.x Node.js compatibility. Infrastructure cost vastly exceeds value of ~5 tests. Revisit when Web codebase is modernized.

**If implemented later**, note from `docs/solutions/jsdom-test-quirks.md`: jsdom normalizes URLs (adds trailing slashes) and expands CSS shorthands (`flex: '1'` → `flex: 1 1 0%`). Use `toContain()` not `toBe()` for URL and CSS assertions.

### Non-Functional Requirements

- [x] All new tests run in under 5 seconds per platform
- [x] No network calls in unit tests (mocked/stubbed)
- [x] No shared mutable state between tests (isolated UserDefaults/prefs)
- [x] CI runs all tests on every push (existing CI already does this)
- [x] `@MainActor` annotation on all iOS test classes testing MainActor types

### Quality Gates

- [x] `swift test` passes with 0 failures (target: ~143 tests total, ~45 new)
- [x] `./gradlew test` passes with 0 failures (target: ~75 tests total, ~20 new)
- [x] Cross-platform fixtures produce identical output on iOS and Android
- [x] All tests complete in under 2 seconds per platform (no flaky timers)
- [x] No global mutable state shared between tests (isolated UserDefaults, ephemeral URLSession)

## Implementation Notes

### File Locations

**iOS** (all in `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/`):
- `ActionDispatcherTests.swift` — action handler tests
- `SecurityTests.swift` — blocked headers/schemes/expressions
- `ViewModelTests.swift` — load lifecycle, render, navigation
- `ComponentDispatchTests.swift` — type→component mapping
- `StateManagerBindingTests.swift` — Binding factory tests

**Android** (all in `JASONETTE-Android/JasonetteApp/app/src/test/java/com/jasonette/`):
- `StateManagerTest.kt` — state + cache ops
- `StyleModifierTest.kt` — multi-class, inline override
- `ColorParsingTest.kt` — hex, rgb, rgba
- `ActionDispatcherTest.kt` — implemented actions

**Cross-platform** (shared fixtures at repo root):
- `test-fixtures/template-simple.json` — basic interpolation
- `test-fixtures/template-each.json` — #each directive
- `test-fixtures/template-if.json` — #if conditional
- `test-fixtures/template-expressions.json` — arithmetic, ternary, member access
- `test-fixtures/document-full.json` — complete $jason document

**Web**: Deferred (see Phase 4 notes)

### Key Patterns

iOS test structure:
```swift
@MainActor
final class ActionDispatcherTests: XCTestCase {
    private var stateManager: StateManager!
    private var dispatcher: ActionDispatcher!
    private let suiteName = "test-\(UUID().uuidString)"

    override func setUp() {
        let defaults = UserDefaults(suiteName: suiteName)!
        stateManager = StateManager(defaults: defaults)
        // Ephemeral session with StubURLProtocol for network tests
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        dispatcher = ActionDispatcher(stateManager: stateManager, session: session)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func testSetUpdatesState() async {
        let action = JasonAction(type: "$set", options: ["key": AnyCodable("value")])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.local["key"] as? String, "value")
    }

    func testTimerStartFiresSuccess() async {
        let expectation = expectation(description: "timer fires")
        // Use 0.01s interval to keep test fast
        let action = JasonAction(
            type: "$timer.start",
            options: ["interval": AnyCodable(0.01), "repeats": AnyCodable(false)],
            success: JasonAction(type: "$set", options: ["fired": AnyCodable(true)])
        )
        await dispatcher.execute(action)
        // Wait for timer to fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { expectation.fulfill() }
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(stateManager.local["fired"] as? Bool, true)
    }
}
```

Android test structure:
```kotlin
class StyleModifierTest {
    @Test
    fun testSingleClassResolution() {
        val styles = mapOf("bold" to JasonStyle(font = "bold"))
        val result = resolveStyle(inline = null, headStyles = styles, className = "bold")
        assertEquals("bold", result?.font)
    }
}
```

Cross-platform fixture format:
```json
{
  "template": {"body": "Hello {{name}}"},
  "context": {"name": "world"},
  "expected": "Hello world"
}
```

### Dependencies to Add

- **iOS**: None (XCTest only, StubURLProtocol as test helper class)
- **Android**: None (JUnit4 + coroutines-test already in build.gradle.kts)
- **Web**: Deferred

### Refactoring Required (before writing tests)

1. **iOS `StateManager.init(defaults:)`** — add `defaults: UserDefaults = .standard` parameter. One-line change, fully backward compatible.
2. **iOS `ActionDispatcher.init(stateManager:session:)`** — add `session: URLSession = .shared` parameter. Store as property, use instead of `URLSession.shared` in `networkRequest`. One-line init change + one-line usage change.
3. **Android `resolveStyle`** — change from `private` to `internal` for test access. Or test via `buildStyleModifier` public API (preferred — no visibility change needed).
4. **Android `parseCssColor` / `parseHexColor` / `parseRgbColor`** — already public, no changes needed.

## References

- Existing iOS tests: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/`
- Existing Android tests: `JASONETTE-Android/JasonetteApp/app/src/test/java/com/jasonette/`
- "Tests Pass But Feature Is Broken": `docs/solutions/test-failures/tests-pass-but-feature-broken.md`
- Android state hoisting: `docs/solutions/android-compose-state-hoisting.md`
- PR #8 (audit fixes): https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/pull/8
