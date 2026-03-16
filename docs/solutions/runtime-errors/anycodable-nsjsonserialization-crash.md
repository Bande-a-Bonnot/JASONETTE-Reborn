---
title: "AnyCodable wrapper types crash NSJSONSerialization"
date: 2026-03-15
category: runtime-errors
tags: [swift, anycodable, json, nsjsonserialization, objc-exception, testflight, crash]
module: Jasonette Core
symptom: "NSInvalidArgumentException in NSJSONSerialization.data(withJSONObject:)"
---

# AnyCodable Wrapper Types Crash NSJSONSerialization

## Problem

TestFlight builds crash with `NSInvalidArgumentException` from `NSJSONSerialization.data(withJSONObject:)`. The crash is **uncatchable** in Swift because it's an Objective-C exception, not a Swift `Error`. Standard `do/catch` blocks do not intercept it.

### Symptoms

- 10 TestFlight crash reports all pointing to `NSJSONSerialization`
- Crashes appear on every screen where templates are rendered
- Stack trace shows the crash inside Foundation's JSON serializer
- Cannot reproduce with unit tests that use pure Swift types

### Root Cause

`JSONDecoder` wraps decoded values in `AnyCodable` wrapper types when decoding `[String: AnyCodable]` dictionaries. When these wrapped values are passed directly to `NSJSONSerialization.data(withJSONObject:)`, the serializer encounters `AnyCodable` instead of native Swift types (`String`, `Int`, `[Any]`, etc.) and throws an ObjC `NSInvalidArgumentException`.

The key insight: **ObjC exceptions bypass Swift's error handling entirely**. `do/catch` cannot save you. You must prevent the exception from being thrown in the first place.

## Solution

### 1. Add `unwrapped` property to AnyCodable

Recursively strip all `AnyCodable` wrappers, returning native Swift types:

```swift
public var unwrapped: Any {
    unwrapped(depth: 0)
}

private func unwrapped(depth: Int) -> Any {
    func recurse(_ value: Any, depth: Int) -> Any {
        guard depth < Self.maxUnwrapDepth else { return value }
        if let codable = value as? AnyCodable {
            return recurse(codable.value, depth: depth + 1)
        }
        if let array = value as? [Any] {
            return array.map { recurse($0, depth: depth + 1) }
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues { recurse($0, depth: depth + 1) }
        }
        return value
    }
    return recurse(self.value, depth: depth)
}
```

Key details:
- Must increment depth on **every** recursive call, including AnyCodable-to-AnyCodable unwrap
- Inner `recurse` function handles `Any` values at every nesting level, not just direct `AnyCodable` instances
- Depth cap (64) prevents stack overflow on pathological input

### 2. Pre-validate with `isValidJSONObject` at every call site

Before every `JSONSerialization.data(withJSONObject:)` call:

```swift
guard JSONSerialization.isValidJSONObject(rendered) else {
    // fallback path
    return
}
let data = try JSONSerialization.data(withJSONObject: rendered)
```

### 3. Four call sites to fix

1. **JasonetteViewModel.render()** — template rendering output
2. **ActionDispatcher.networkRequest()** — request body serialization
3. **StateManager.persistCache()** — cache persistence to UserDefaults
4. **StateManager.cacheSet()** — validate before merging into cache

## Learnings

### ObjC/Swift Exception Boundary

Swift `do/catch` only catches Swift `Error`. ObjC `NSException` (like `NSInvalidArgumentException`) crashes through `catch` blocks. The only defense is prevention via `isValidJSONObject`.

### AnyCodable Unwrapping Must Be Fully Recursive

The initial implementation only checked `value as? AnyCodable` at the top level. Gemini Code Assist correctly flagged that nested containers (`[Any]` containing `AnyCodable`) weren't recursed into. The fix: an inner `recurse(_ value: Any, depth:)` function that handles `Any` at every level.

### Depth Must Increment Consistently

The initial Gemini-suggested fix didn't increment depth when unwrapping AnyCodable-to-AnyCodable (only on container descent). The 5-agent review caught this: without incrementing, a chain of 65+ nested `AnyCodable` wrappers bypasses the depth guard.

### ExpressionParser Needs Its Own Depth Guard

The ExpressionEvaluator had `maxDepth = 20` for AST resolution, but the **parser** itself had no recursion limit. Deeply nested expressions like `(((((...))))))` could stack overflow during parsing before the evaluator ever runs. Fixed with `enterDepth()/leaveDepth()` guards (max 50).

### NSLock Was Unnecessary (Entire Call Chain is @MainActor)

The code-simplicity reviewer traced the call chain: `ExpressionEvaluator.evaluate` is only called from `TemplateEngine`, which is only called from `JasonetteViewModel.render()`, which is `@MainActor`. The NSLock added for thread safety was protecting a cache that can never be accessed concurrently. Removed it in favor of a comment documenting the threading contract.

### Dictionary.keys.first! Is Not LRU Eviction

Swift dictionaries are unordered. `_nodeCache.removeValue(forKey: _nodeCache.keys.first!)` is pseudo-random eviction, not FIFO or LRU. For a bounded cache, `removeAll(keepingCapacity: true)` is simpler and honest about what it does.

### body.header.menu Is a Nav Bar Button, Not a Component

The Jasonette spec defines `body.header.menu` as a navigation bar button item. It has `text` and `href` but no `type` field. Rendering it via `ComponentView` (which dispatches on `type`) produced `[Unknown: nil]` on every screen. Fix: render as `.toolbar { ToolbarItem(.primaryAction) }`.

### handleHref Scheme Allowlist Must Match NavigationView

`JasonetteViewModel.handleHref` validated only `http/https`, but `JasonetteNavigationView` also supports `mailto/tel/sms` for `view: "app"`. The stricter filter silently blocked legitimate features. Fix: expand the allowlist when `href.view == "app"`.

### Bot Review Comments Are Consistently High-Quality

Gemini Code Assist and GitHub Copilot produced 9 review comments, all valid:
- Gemini caught the non-recursive unwrapping bug
- Copilot caught 8 issues including NSLock data race potential, depth off-by-one, CancellationError handling, test quality, and doc accuracy

### Multi-Agent Review Catches What Single-Pass Misses

Five specialized review agents (security, performance, architecture, simplicity, pattern-recognition) ran in parallel and found issues the bot reviews missed:
- ExpressionParser unbounded recursion (P1 security finding)
- NSLock being unnecessary (simplicity)
- handleHref blocking tel/mailto (architecture/security)
- Cache eviction being O(n) and non-deterministic (performance)

## Prevention

1. **Always call `.unwrapped` before passing AnyCodable data to Foundation APIs**
2. **Always pre-validate with `isValidJSONObject` before `JSONSerialization.data(withJSONObject:)`**
3. **Add depth guards to all recursive parsers and evaluators** — not just the resolution phase
4. **Trace the full call chain** before adding synchronization primitives — you may not need them
5. **Run multi-agent reviews** on security-sensitive code; different agents catch different categories of issues

## Related

- `docs/solutions/swift-recursive-codable-structs.md` — related Codable recursion patterns
- `docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md` — project context
- PR #10: https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/pull/10
