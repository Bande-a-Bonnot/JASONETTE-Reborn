---
status: pending
priority: p2
issue_id: "007"
tags: [code-review, security, performance, template-engine]
dependencies: [001]
---

# `#each` Directive Has No Iteration Cap — Memory Amplification DoS

## Problem Statement

`TemplateEngine.applyDirective(.each)` iterates every element of an array with no maximum count. Combined with the state-overwrite vector (todo #001), a server can inject an array with tens of thousands of elements into state, causing the template engine to allocate a rendered copy of the item template for each element, exhausting memory.

## Findings

**File:** `Sources/Jasonette/Template/TemplateEngine.swift`

```swift
guard let items = value as? [Any] else { return [] }
var result: [Any] = []
for (index, item) in items.enumerated() {
    // No upper bound check
    result.append(render(itemTemplate, context: itemContext, depth: depth + 1))
}
```

With a complex item template and 10,000 elements, the engine allocates 10,000 rendered dicts before the view can reject any. This is consistent with the existing `maxDepth` guard philosophy — the engine already bounds recursion depth; it should also bound iteration width.

## Proposed Solutions

### Option A: Add `maxItems` constant alongside `maxDepth`
```swift
static let maxItems = 1000

for (index, item) in items.prefix(maxItems).enumerated() {
    ...
}
// Optionally log a warning if items.count > maxItems
```
- Pros: One-liner, mirrors maxDepth pattern
- Cons: Silently truncates long lists

### Option B: Log and truncate
Same as A but emit a `print("[Jasonette] #each: truncated \(items.count) items to \(maxItems)")` warning in debug builds.

## Recommended Action
Option B — truncation with debug warning.

## Technical Details
- **Affected files:** `Template/TemplateEngine.swift` (applyDirective .each case)
- **Effort:** Small

## Acceptance Criteria
- [ ] `#each` with 10,000 items only renders `maxItems` items
- [ ] Warning logged in debug builds when truncation occurs
- [ ] Test: `testEachTruncatesAtMaxItems`
- [ ] Existing `#each` tests with small arrays still pass

## Work Log
- 2026-03-12: Identified by security-sentinel agent during code review
