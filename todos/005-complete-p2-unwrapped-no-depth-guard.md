---
status: pending
priority: p2
issue_id: "005"
tags: [code-review, security, performance, anycOdable]
dependencies: []
---

# `AnyCodable.unwrapped` Has No Depth Guard — Stack Overflow DoS

## Problem Statement

`AnyCodable.unwrapped` is mutually recursive with no depth limit. A server delivering deeply-nested JSON (up to `JSONDecoder`'s default 512-level limit) can cause a stack overflow crash when `unwrapped` is called on the decoded value. `TemplateEngine.render()` and `ExpressionEvaluator.resolve()` both have depth guards (20 levels); `unwrapped` has none, creating a gap in the DoS protection.

## Findings

**File:** `Sources/Jasonette/Core/AnyCodable.swift`

```swift
public var unwrapped: Any {
    switch value {
    case let arr as [AnyCodable]:
        return arr.map(\.unwrapped)  // unbounded recursion
    case let dict as [String: AnyCodable]:
        return dict.mapValues(\.unwrapped)  // unbounded recursion
    ...
    }
}
```

A crafted JSON payload `[[[...(512 levels)...]]]` decodes successfully (JSONDecoder handles it iteratively), then calling `.unwrapped` blows the stack.

## Proposed Solutions

### Option A: Add depth parameter (cleanest)

```swift
public var unwrapped: Any { unwrapped(depth: 0) }

private func unwrapped(depth: Int) -> Any {
    guard depth < 64 else { return value }
    switch value {
    case let arr as [AnyCodable]:
        return arr.map { $0.unwrapped(depth: depth + 1) }
    case let dict as [String: AnyCodable]:
        return dict.mapValues { $0.unwrapped(depth: depth + 1) }
    default: return value
    }
}
```
- Pros: Mirrors existing depth-guard pattern in TemplateEngine/ExpressionEvaluator
- Cons: Slightly more boilerplate

### Option B: Iterative implementation with explicit stack

Convert to iterative traversal using an explicit work stack. Zero stack overflow risk.
- Pros: Most robust
- Cons: More complex implementation

## Recommended Action

Option A — consistent with existing depth-guard pattern.

## Technical Details

- **Affected files:** `Core/AnyCodable.swift`
- **Effort:** Small

## Acceptance Criteria

- [ ] `unwrapped` on a 512-level deeply-nested AnyCodable does not crash
- [ ] Test: `testUnwrappedHandlesMaxDepthWithoutCrash`
- [ ] Depth limit chosen ≥ practical real-world document depth (≥32)

## Work Log

- 2026-03-12: Identified by security-sentinel agent during code review
