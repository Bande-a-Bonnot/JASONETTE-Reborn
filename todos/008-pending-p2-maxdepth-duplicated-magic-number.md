---
status: pending
priority: p2
issue_id: "008"
tags: [code-review, architecture, configuration]
dependencies: []
---

# `maxDepth` Duplicated Across Files — Silent Divergence Risk

## Problem Statement

`TemplateEngine` defines `static let maxDepth = 20` as a named constant. `ExpressionEvaluator.resolve()` independently hard-codes `guard depth < 20`. `ActionDispatcher` defines `static let maxTimers = 50`. These are all runtime safety limits owned by their respective leaf implementation types rather than a shared configuration. If one is changed, the others diverge silently.

## Findings

- `TemplateEngine.swift` line 6: `static let maxDepth = 20` ✓ named constant
- `ExpressionEvaluator.swift` line 74: `guard depth < 20 else` ✗ magic literal
- `ActionDispatcher.swift` line 12: `static let maxTimers = 50` — correct pattern but isolated

## Proposed Solutions

### Option A: Add named constant to ExpressionEvaluator
```swift
// ExpressionEvaluator.swift
private static let maxDepth = 20
```
Minimal change, no new files.

### Option B: Shared configuration namespace
Create `Sources/Jasonette/Core/JasonetteConfig.swift`:
```swift
public enum JasonetteConfig {
    public static let maxTemplateDepth = 20
    public static let maxTimers = 50
    public static let maxEachItems = 1000
}
```
Both `TemplateEngine` and `ExpressionEvaluator` reference `JasonetteConfig.maxTemplateDepth`.
- Pros: Single source of truth for all tunable limits, testable as a group
- Cons: Minor overhead of a new file

## Recommended Action
Option A immediately (one-liner). Option B in a follow-up when todo #007 adds `maxItems`.

## Technical Details
- **Affected files:** `Template/ExpressionEvaluator.swift` line 74
- **Effort:** Trivial

## Acceptance Criteria
- [ ] No magic number `20` in `ExpressionEvaluator.resolve()`
- [ ] `TemplateEngine.maxDepth` and `ExpressionEvaluator`'s equivalent have the same value by definition

## Work Log
- 2026-03-12: Identified by architecture-strategist and pattern-recognition-specialist agents during code review
