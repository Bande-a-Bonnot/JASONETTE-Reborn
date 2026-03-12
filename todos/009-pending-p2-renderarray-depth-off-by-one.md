---
status: pending
priority: p2
issue_id: "009"
tags: [code-review, correctness, template-engine]
dependencies: []
---

# `renderArray` Passes `depth` (not `depth+1`) to `applyDirective`

## Problem Statement

In `TemplateEngine.renderArray`, non-directive items call `render(item, context:, depth: depth + 1)` — incrementing depth. But directive items call `applyDirective(directive, ..., depth: depth)` — not incrementing depth at the array level. Directives therefore consume one fewer depth slot per nesting level, making the effective maximum recursion depth for directive-heavy templates slightly higher than for plain templates.

## Findings

**File:** `Sources/Jasonette/Template/TemplateEngine.swift`

```swift
static func renderArray(_ arr: [Any], context: [String: Any], depth: Int) -> [Any] {
    for item in arr {
        if let dict = item as? [String: Any], let directive = findDirective(dict) {
            let rendered = applyDirective(directive, ..., depth: depth)     // ← should be depth + 1
            ...
        } else {
            result.append(render(item, ..., depth: depth + 1))              // ← correctly increments
        }
    }
}
```

`applyDirective` then calls `render(..., depth: depth + 1)` internally, but the "array level" increment is missing. A directive at depth N actually runs as if it were at depth N (not N+1), allowing one extra level of nesting compared to a plain template at the same position.

## Proposed Solutions

### Option A: Pass `depth + 1` to `applyDirective`
```swift
let rendered = applyDirective(directive, template: dict, context: context, depth: depth + 1)
```
- Pros: Uniform depth accounting throughout the engine
- Cons: Slightly reduces the effective max depth for directive-heavy templates (from ~21 to 20 levels, which is still within spec)

## Recommended Action
Option A — one character change.

## Technical Details
- **Affected files:** `Template/TemplateEngine.swift` (renderArray method)
- **Effort:** Trivial

## Acceptance Criteria
- [ ] `renderArray` passes `depth + 1` to `applyDirective`
- [ ] All existing `#each` and `#if` tests still pass
- [ ] Depth guard test confirms deeply-nested directive trees are handled correctly

## Work Log
- 2026-03-12: Identified by architecture-strategist agent during code review
