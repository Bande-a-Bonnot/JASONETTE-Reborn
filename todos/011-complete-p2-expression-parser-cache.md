---
status: pending
priority: p2
issue_id: "011"
tags: [code-review, performance, template-engine]
dependencies: []
---

# Expression Parser Allocates Fresh Instance Per `{{expr}}` Token

## Problem Statement

`ExpressionEvaluator.evaluate()` constructs a new `ExpressionParser` instance for every expression string on every render. Expression strings are static (defined in the JSON template), so parsing them repeatedly is wasteful. For a document with 50 `{{...}}` tokens rendered multiple times, this is hundreds of unnecessary parser allocations.

## Findings

**File:** `Sources/Jasonette/Template/ExpressionEvaluator.swift`

```swift
public static func evaluate(_ expression: String, context: [String: Any]) -> Any? {
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let parser = ExpressionParser(trimmed)  // new allocation every call
    ...
}
```

Parsing (tokenization + AST construction) is static relative to the template string. Resolution against context is dynamic. These can be separated: parse once, resolve many times.

## Proposed Solutions

### Option A: Thread-safe expression cache
```swift
private static let nodeCacheLock = NSLock()
private static var nodeCache: [String: Node] = [:]

public static func evaluate(_ expression: String, context: [String: Any]) -> Any? {
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    nodeCacheLock.lock()
    let cached = nodeCache[trimmed]
    nodeCacheLock.unlock()

    let node: Node
    if let cached { node = cached }
    else {
        guard let parsed = try? ExpressionParser(trimmed).parse() else { return nil }
        nodeCacheLock.lock()
        nodeCache[trimmed] = parsed
        nodeCacheLock.unlock()
        node = parsed
    }
    return resolve(node, context: context)
}
```

### Option B: Use NSCache for automatic memory pressure eviction
Replace `[String: Node]` with `NSCache<NSString, AnyObject>`.
- Pros: OS manages memory automatically
- Cons: More complex wrapping for value types

## Recommended Action
Option A with a bounded dictionary (cap at 256 entries with simple LRU). `ExpressionEvaluator` is already `@MainActor`-isolated via its callers so the lock may not be needed — confirm actor isolation before adding it.

## Technical Details
- **Affected files:** `Template/ExpressionEvaluator.swift`
- **Effort:** Small

## Acceptance Criteria
- [ ] Identical expression strings reuse the parsed AST
- [ ] Cache is bounded (does not grow unbounded on documents with many unique expressions)
- [ ] All existing expression evaluator tests pass

## Work Log
- 2026-03-12: Identified by performance-oracle agent during code review
