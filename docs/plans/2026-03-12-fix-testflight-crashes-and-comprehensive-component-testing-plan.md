---
title: "Fix TestFlight Crashes and Comprehensive Component Testing"
type: fix
date: 2026-03-12
---

# Fix TestFlight Crashes and Comprehensive Component Testing

## Enhancement Summary

**Deepened on:** 2026-03-12
**Research agents used:** 10 (architecture-strategist, performance-oracle, security-sentinel, code-simplicity-reviewer, pattern-recognition-specialist, best-practices-researcher x2, learnings-researcher x2, repo-research-analyst)

### Key Improvements from Research
1. **Simpler root cause identified**: The crash is caused by `AnyCodable` wrapper types not being unwrapped — NOT by the template engine producing bad values. Fix is `AnyCodable.unwrapped` (~10 lines), not a new `JSONSanitizer` file.
2. **Four call sites affected**, not just one: `render()`, `networkRequest()`, `persistCache()`, `JSON.stringify`
3. **Security vulnerabilities discovered**: property blocklist bypassable via bracket notation, SSRF vector in `$network.request`, no URL scheme validation in `DocumentLoader`
4. **Performance quick wins**: fast-path `str.contains("{{")` in TemplateEngine, batch `StateManager` cache mutations

---

## Overview

All 10 TestFlight crash reports share a single root cause: an ObjC exception thrown by `NSJSONSerialization` in `JasonetteViewModel.render(_:)` at line 99. The existing `do/catch` block cannot catch ObjC exceptions. After fixing the crash, we systematically test every component to prevent regressions.

## Problem Statement

### Crash Analysis

**10 crash reports, 1 root cause.** Every crash has this identical stack trace:

```
NSJSONSerialization.dataWithJSONObject:options:error:
  → JasonetteViewModel.render(_:) + 900 (JasonetteViewModel.swift:99)
  → JasonetteViewModel.load() + 304 (JasonetteViewModel.swift:76)
  → JasonetteView.body.getter (JasonetteView.swift:51)
```

**Affected screens** (from user feedback comments):
1. Components → button
2. Action → Session
3. Action → Vision
4. Action → Variable
5. Actions → Address Book
6. Action → geo.get
7. Action → script.include
8. Action → Timer → stopwatch
9. Action → Timer → Mario
10. Core → render → multiple templates

### Root Cause (Refined)

`AnyCodable.value` returns `Any`, but nested values remain as `[AnyCodable]` or `[String: AnyCodable]` — **not** raw `[Any]` or `[String: Any]`. When `head.data?.compactMapValues { $0.value }` extracts values, it unwraps only one level. These wrapped types pass through `TemplateEngine.render()` unchanged (failing `as? [Any]` and `as? [String: Any]` casts, hitting the `return template` default path). When `NSJSONSerialization` encounters these `AnyCodable`-wrapped types, it throws an **ObjC `NSInvalidArgumentException`** — not a Swift `Error`. Swift's `do/catch` cannot intercept ObjC exceptions, so the app aborts with `SIGABRT`.

**Why all 10 screens crash**: Any screen that uses `head.templates` triggers the `render()` path. The crash happens on the re-serialization step regardless of which component is being rendered.

### Research Insight: Four Affected Call Sites

The same class of bug exists at **four locations** in the codebase:

| # | File | Line | Call |
|---|------|------|------|
| 1 | `JasonetteViewModel.swift` | 99 | `JSONSerialization.data(withJSONObject: rendered)` — **the crash** |
| 2 | `ActionDispatcher.swift` | 192 | `JSONSerialization.data(withJSONObject: body.value)` — network request body |
| 3 | `StateManager.swift` | 90 | `JSONSerialization.data(withJSONObject: cache)` — cache persistence |
| 4 | `ExpressionEvaluator.swift` | 56 | `JSONSerialization.data(withJSONObject: val)` — `JSON.stringify` |

All four pass untyped `Any` to `NSJSONSerialization` without validation.

## Proposed Solution

### Phase 1: Fix the Crash (Critical — ~15 lines of code)

#### 1a. Add `unwrapped` to `AnyCodable` (no new files)

Add a computed property to `AnyCodable` that recursively converts nested `AnyCodable` wrappers to native Swift types:

```swift
// Sources/Jasonette/Core/AnyCodable.swift — add to existing file
extension AnyCodable {
    /// Recursively unwrap AnyCodable wrappers to native JSON types.
    public var unwrapped: Any {
        switch value {
        case let arr as [AnyCodable]:
            return arr.map(\.unwrapped)
        case let dict as [String: AnyCodable]:
            return dict.mapValues(\.unwrapped)
        case let arr as [Any]:
            return arr.map { ($0 as? AnyCodable)?.unwrapped ?? $0 }
        case let dict as [String: Any]:
            return dict.mapValues { ($0 as? AnyCodable)?.unwrapped ?? $0 }
        default:
            return value
        }
    }
}
```

#### 1b. Fix `JasonetteViewModel.render(_:)` — use `unwrapped`

```swift
private func render(_ doc: JasonDocument) {
    let head = doc.jason.head
    let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]  // Changed: .value → .unwrapped
    let context = data.merging(stateManager.local) { _, new in new }

    if let templates = head?.templates?.body {
        let rendered = TemplateEngine.render(templates.unwrapped, context: context)  // Changed: .value → .unwrapped

        guard JSONSerialization.isValidJSONObject(rendered) else {
            renderedRoot = doc.jason
            return
        }
        do {
            let renderedData = try JSONSerialization.data(withJSONObject: rendered)
            var root = try JSONDecoder().decode(JasonRoot.self, from: renderedData)
            root.head = head
            renderedRoot = root
        } catch {
            renderedRoot = doc.jason
        }
    } else {
        renderedRoot = doc.jason
    }
}
```

#### 1c. Fix the other three call sites

**ActionDispatcher.swift** line 192:
```swift
// Before:
if let data = try? JSONSerialization.data(withJSONObject: body.value as Any) {
// After:
if let data = try? JSONSerialization.data(withJSONObject: body.unwrapped) {
```

**StateManager.swift** line 90 — `persistCache()`: cache values come from `$cache.set` which uses `compactMapValues { $0.value }`. Ensure cache values are unwrapped before persistence.

**ExpressionEvaluator.swift** line 56 — `JSON.stringify`: add `isValidJSONObject` guard before serialization.

#### 1d. Tests for the crash fix

Add to **existing** `AnyCodableTests.swift`:
```swift
- testUnwrappedConvertsNestedAnyCodableArrays()
- testUnwrappedConvertsNestedAnyCodableDicts()
- testUnwrappedPreservesNativeTypes()
- testUnwrappedHandlesDeeplyNestedStructures()
```

Add to **existing** `ViewModelTests.swift`:
```swift
- testRenderWithTemplatedDocumentDoesNotCrash()
- testRenderWithAnyCodableWrappedDataProducesValidOutput()
```

### Phase 2: Systematic Component Testing

Review and test every component. Below is the full inventory.

#### Components (SwiftUI Views)

| # | Component | File | Existing Tests | New Tests Needed |
|---|-----------|------|---------------|-----------------|
| 1 | `LabelComponent` | `Components/LabelComponent.swift` | ComponentDispatchTests | Text rendering, empty text, long text |
| 2 | `ImageComponent` | `Components/ImageComponent.swift` | ComponentDispatchTests | URL handling, nil URL, style application |
| 3 | `ButtonComponent` | `Components/ButtonComponent.swift` | ComponentDispatchTests | Text+URL variants, nil text |
| 4 | `TextFieldComponent` | `Components/TextFieldComponent.swift` | StateManagerBindingTests | Keyboard types, placeholder, state binding |
| 5 | `TextAreaComponent` | `Components/TextAreaComponent.swift` | StateManagerBindingTests | Multi-line input, state binding |
| 6 | `SliderComponent` | `Components/SliderComponent.swift` | StateManagerBindingTests | Value range, initial value, state binding |
| 7 | `SpaceComponent` | `Components/SpaceComponent.swift` | ComponentDispatchTests | Custom height, default height |
| 8 | `SwitchComponent` | `Components/SwitchComponent.swift` | StateManagerBindingTests | Toggle state, initial value |
| 9 | `MapStubComponent` | `Components/MapStubComponent.swift` | ComponentDispatchTests | Stub renders placeholder |
| 10 | `LayoutView` | `Components/LayoutView.swift` | None | Vertical/horizontal, nested, empty |
| 11 | `ComponentView` | `Components/ComponentRegistry.swift` | ComponentDispatchTests | All type dispatch, unknown fallback, href/action wrapping |
| 12 | `JasonStyleModifier` | `Components/JasonStyleModifier.swift` | StyleModifierTests | All style props, class-based styles |

#### Core

| # | Module | File | Existing Tests | New Tests Needed |
|---|--------|------|---------------|-----------------|
| 13 | `AnyCodable` | `Core/AnyCodable.swift` | AnyCodableTests | `unwrapped` tests (Phase 1d) |
| 14 | `DocumentLoader` | `Core/DocumentLoader.swift` | None | Network loading, error handling, invalid JSON |
| 15 | `JasonDocument` | `Core/JasonDocument.swift` | JasonDocumentTests | Coverage good |
| 16 | `ActionDispatcher` | `Core/ActionDispatcher.swift` | ActionDispatcherTests | Timer reentrancy, all action types |
| 17 | `StateManager` | `Core/StateManager.swift` | StateManagerTests + BindingTests | Coverage good |

#### Template Engine

| # | Module | File | Existing Tests | New Tests Needed |
|---|--------|------|---------------|-----------------|
| 18 | `TemplateEngine` | `Template/TemplateEngine.swift` | TemplateEngineTests | AnyCodable-wrapped input edge cases |
| 19 | `ExpressionParser` | `Template/ExpressionParser.swift` | ExpressionParserTests | Coverage good |
| 20 | `ExpressionEvaluator` | `Template/ExpressionEvaluator.swift` | ExpressionParserTests (indirect) | Direct eval tests, callable ref path |

#### Rendering

| # | Module | File | Existing Tests | New Tests Needed |
|---|--------|------|---------------|-----------------|
| 21 | `JasonetteViewModel` | `Rendering/JasonetteViewModel.swift` | ViewModelTests | Crash reproduction (Phase 1d) |
| 22 | `JasonetteView` | `Rendering/JasonetteView.swift` | None | Skip (UI tests) |
| 23 | `JasonetteNavigationView` | `Rendering/JasonetteNavigationView.swift` | None | Navigation stack behavior |

### Research Insights: Testing Best Practices

**From learnings and best-practices research:**

- **Use `StubURLProtocol` with URL-keyed map** for DocumentLoaderTests (already exists in codebase as `StubURLProtocol.swift`)
- **Extract shared test helpers** into `TestHelpers.swift` — `makeDocument`, `simpleDocument`, `decodeAction` are duplicated across 4 test files
- **Add recursion depth guard** to `TemplateEngine.render()` (currently has none, unlike `ExpressionEvaluator` which caps at 20)
- **Test `ExpressionEvaluator` line 92** explicitly — callable reference path (`Math.floor` without parens leaks string into output)

### Phase 3: Quick Performance Wins

**From performance-oracle review:**

#### 3a. TemplateEngine fast-path for non-template strings
```swift
// In TemplateEngine.interpolateString — add before regex:
guard str.contains("{{") else { return str }
```
~90% of strings contain no expressions. This skips regex allocation entirely.

#### 3b. StateManager batch cache mutations
`cacheSet` triggers `didSet` (UserDefaults write) per key. Batch into single swap:
```swift
public func cacheSet(_ values: [String: Any]) {
    var updated = cache
    for (key, value) in values { updated[key] = value }
    cache = updated  // Single didSet trigger
}
```

#### 3c. Timer reentrancy guard
Timer-fired actions create a `Task` per tick with no reentrancy guard. If an action yields (e.g., network request), the next tick enqueues overlapping execution. Add a `Set<String>` of in-flight timer names.

### Phase 4: Security Hardening (Follow-up)

**From security-sentinel review — document as future work:**

1. **Property blocklist bypass**: `__proto__`/`constructor`/`prototype` check only applies to dot access (`obj.constructor`) but not bracket access (`obj["constructor"]`). Fix: apply blocklist in `computedMember` case too.
2. **DocumentLoader URL scheme**: No validation — accepts `file:///`. Add http/https allowlist matching `$network.request`.
3. **SSRF via `$network.request`**: No private IP blocking. Malicious JSON can hit `127.0.0.1`, cloud metadata `169.254.169.254`, LAN. Consider private IP blocklist.
4. **TemplateEngine recursion depth**: No limit (unlike ExpressionEvaluator's 20). Add `depth` parameter.
5. **Network response state injection**: `$network.request` merges response directly into `stateManager.local` without namespacing. Attacker-controlled API can overwrite UI state.

## Acceptance Criteria

### Functional Requirements
- [ ] All 10 crash scenarios no longer crash (validated by unit tests)
- [ ] `AnyCodable.unwrapped` recursively unwraps nested wrappers
- [ ] `isValidJSONObject()` guard before serialization in `render()`
- [ ] All four `JSONSerialization` call sites use unwrapped/validated input
- [ ] Graceful fallback to raw document on serialization failure
- [ ] Every component type has at least 2 unit tests
- [ ] All existing 97 tests continue to pass
- [ ] New tests bring total to 120+

### Quality Gates
- [ ] `swift build` succeeds
- [ ] `swift test` passes all tests
- [ ] No force-unwraps in new code
- [ ] No ObjC exception paths remain unguarded

## Implementation Order

1. Add `unwrapped` computed property to `AnyCodable` (existing file)
2. Fix `JasonetteViewModel.render(_:)` to use `unwrapped` + `isValidJSONObject`
3. Fix three other `JSONSerialization` call sites
4. Write crash reproduction tests in `AnyCodableTests.swift` and `ViewModelTests.swift`
5. Add TemplateEngine fast-path (`str.contains("{{")`)
6. Add TemplateEngine recursion depth guard
7. Batch `StateManager.cacheSet` mutations
8. Add timer reentrancy guard in `ActionDispatcher`
9. Write `DocumentLoaderTests.swift` using existing `StubURLProtocol`
10. Expand `ComponentDispatchTests.swift` for every component type
11. Write `ExpressionEvaluatorTests.swift` (direct evaluation, callable ref edge case)
12. Expand `ActionDispatcherTests.swift` for timer edge cases
13. Expand `TemplateEngineTests.swift` for AnyCodable-wrapped input
14. Run full test suite, verify all pass
15. Apply property blocklist to computed member access (security)
16. Add URL scheme validation to DocumentLoader (security)

## References

### Institutional Learnings Applied
- `docs/solutions/test-failures/ios-test-isolation-patterns.md` — DI patterns for UserDefaults, URLSession, timers
- `docs/solutions/test-failures/tests-pass-but-feature-broken.md` — tiered testing strategy
- `docs/solutions/swift-recursive-codable-structs.md` — JasonComponent/JasonAction use `final class` for recursion
- `docs/solutions/build-errors/swiftui-modifier-gotchas.md` — nil modifier values override parent styles
- `docs/solutions/build-errors/swift-canImport-vs-os-platform-check.md` — use `#if os(iOS)` not `#if canImport`
