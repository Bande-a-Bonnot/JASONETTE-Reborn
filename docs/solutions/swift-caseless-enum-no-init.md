---
title: "Swift Caseless Enums Cannot Be Instantiated"
category: debugging-patterns
tags: [swift, enum, namespace, static-methods]
module: iOS
symptom: "'X' cannot be constructed because it has no accessible initializers"
root_cause: "Caseless enums are namespaces — use static methods, not instances"
---

# Swift Caseless Enums Cannot Be Instantiated

## Problem

Caseless enums used as namespaces for static methods cannot be
instantiated with `X()`:

```swift
public enum TemplateEngine {
    public static func render(...) { ... }
}

// FAILS:
let engine = TemplateEngine()  // no accessible initializers
engine.render(...)
```

## Solution

Call static methods directly:

```swift
TemplateEngine.render(template, context: context)
```

## When to Use Caseless Enums

Use `enum` instead of `struct` for pure namespaces (no state) to prevent
accidental instantiation. This is a Swift convention.
