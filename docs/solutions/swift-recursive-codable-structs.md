---
title: "Swift Recursive Codable Structs Need Class"
category: configuration-fixes
tags: [swift, codable, recursive, struct, class]
module: iOS
symptom: "error: value type 'X' has infinite size"
root_cause: "Swift structs cannot recursively contain themselves"
---

# Swift Recursive Codable Structs Need Class

## Problem

Swift structs that reference themselves (directly or indirectly) produce
compile error: `value type 'X' has infinite size`.

```swift
// FAILS:
struct JasonComponent: Codable {
    var components: [JasonComponent]?  // infinite size
}
struct JasonAction: Codable {
    var success: JasonAction?  // infinite size
}
```

## Solution

Convert recursive types to `final class` with `@unchecked Sendable`:

```swift
public final class JasonComponent: Codable, @unchecked Sendable {
    var components: [JasonComponent]?  // works: class uses reference semantics
}
```

## Notes

- `indirect` only works for enums, not structs
- Using `final class` is the simplest solution for Codable hierarchies
- `@unchecked Sendable` is needed if the type must conform to Sendable
- Auto-synthesized Codable conformance still works with classes
