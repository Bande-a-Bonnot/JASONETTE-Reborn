---
status: pending
priority: p1
issue_id: "004"
tags: [code-review, data-integrity, state-management, userdefaults]
dependencies: []
---

# `cacheSet` Non-Serializable Value Silently Poisons All Subsequent Persistence

## Problem Statement

`cacheSet` merges values into `cache` without validation. If any value is non-JSON-serializable, `persistCache()` silently skips the entire write. All subsequent `cacheSet` calls continue to accumulate the bad value in memory, causing every subsequent write to also be silently dropped. The in-memory state diverges permanently from UserDefaults until `cacheReset()` is called.

## Findings

**File:** `Sources/Jasonette/Core/StateManager.swift`

```swift
public func cacheSet(_ values: [String: Any]) {
    cache.merge(values) { _, new in new }  // no validation before merge
}

private func persistCache() {
    guard JSONSerialization.isValidJSONObject(cache) else { return }  // silent drop
    ...
}
```

Scenario: `cacheSet(["token": "abc"])` → persisted correctly. Then `cacheSet(["expiry": Date()])` → merged in memory, guard fires, nothing written. Now `cacheSet(["token": "xyz"])` → guard fires again (Date still in cache), token update also lost.

## Proposed Solutions

### Option A: Validate before merge (recommended)
```swift
public func cacheSet(_ values: [String: Any]) {
    let candidate = cache.merging(values) { _, new in new }
    guard JSONSerialization.isValidJSONObject(candidate) else {
        assertionFailure("[Jasonette] cacheSet: non-serializable value dropped: \(values.keys)")
        return
    }
    cache = candidate
}
```
- Pros: Prevents in-memory corruption, fails loudly in debug, consistent state
- Cons: Entire batch rejected if one value is bad

### Option B: Filter invalid keys, set the rest
Iterate and only merge keys where `JSONSerialization.isValidJSONObject([k: v])` passes.
- Pros: Partial writes succeed
- Cons: Surprising behavior, partial updates hard to reason about

### Option C: Assert at the `AnyCodable` layer
Since `cacheSet` callers in `ActionDispatcher` go through `AnyCodable.value`, the values should already be serializable. Add a runtime assertion in `AnyCodable.value` accessor.
- Pros: Catches the bug at origin
- Cons: Doesn't protect against direct `StateManager.cacheSet` callers

## Recommended Action
Option A — validate the full candidate dict before merging.

## Technical Details
- **Affected files:** `Core/StateManager.swift` (cacheSet method)
- **Effort:** Small

## Acceptance Criteria
- [ ] `cacheSet` with a non-JSON-serializable value does not corrupt subsequent writes
- [ ] Debug build shows an assertion failure or log when invalid value is passed
- [ ] Test: verify that `cacheSet(["good": "val"])` after `cacheSet(["bad": Date()])` still persists "good"

## Work Log
- 2026-03-12: Identified by data-integrity-guardian agent during code review
