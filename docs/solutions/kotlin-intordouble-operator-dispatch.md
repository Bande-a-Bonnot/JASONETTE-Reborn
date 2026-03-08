---
title: "Kotlin intOrDouble operator dispatch bug"
category: debugging-patterns
tags: [kotlin, arithmetic, type-preservation, expression-evaluator]
module: Template Engine
symptom: "Wrong arithmetic results when operands are Double"
root_cause: "Attempted to infer Double operation from Int operation signature"
---

## Problem

When implementing Int-preserving arithmetic in Kotlin, a helper function
tried to determine the Double equivalent of an Int operation by testing
`intOp(1, 1)`. This produced wrong results for subtraction and was
generally fragile.

## Bad Pattern

```kotlin
private fun intOrDouble(l: Any?, r: Any?, op: (Int, Int) -> Int): Any? {
    // ...
    return ld + rd - rd + op(0, 0).toDouble()
        .let { ld.toDoubleOp(rd, op) }
}
```

## Fix

Pass both Int and Double operations explicitly:

```kotlin
private fun intOrDouble(
    l: Any?, r: Any?,
    intOp: (Int, Int) -> Int,
    doubleOp: (Double, Double) -> Double
): Any? {
    val li = l as? Int; val ri = r as? Int
    if (li != null && ri != null) return intOp(li, ri)
    val ld = l?.toDoubleOrNull(); val rd = r?.toDoubleOrNull()
    return if (ld != null && rd != null) doubleOp(ld, rd) else null
}

// Usage:
"-" -> intOrDouble(l, r, Int::minus, Double::minus)
"*" -> intOrDouble(l, r, Int::times, Double::times)
```

## Lesson

Never try to infer operation semantics from a function reference at
runtime. Pass the operations explicitly.

## Extension Function Shadowing (Related)

A separate but related Kotlin pitfall: defining `Any?.toDoubleOrNull()` as an extension function shadows the stdlib's `String.toDoubleOrNull()`. When the receiver is a `String`, Kotlin dispatches to the `Any?` extension (because it's more specific in scope), which internally calls `toString().toDoubleOrNull()` — but `toString()` returns a `String`, so it recurses infinitely.

```kotlin
// BROKEN: infinite recursion when receiver is String
fun Any?.toDoubleOrNull(): Double? = when (this) {
    is Number -> toDouble()
    else -> toString().toDoubleOrNull() // calls itself, not stdlib!
}
```

**Fix:** Use a distinct function name that doesn't shadow stdlib:

```kotlin
fun Any?.asDoubleOrNull(): Double? = when (this) {
    is Number -> toDouble()
    is String -> toDoubleOrNull() // now calls stdlib String.toDoubleOrNull()
    else -> null
}
```

**Symptom:** `StackOverflowError` at runtime, only when the input is a `String` (e.g., `"3.14".toDoubleOrNull()`). `Int` and `Double` inputs work fine because they hit the `is Number` branch.

**Learning:** Never name an extension function identically to a stdlib method on a supertype — Kotlin's dispatch rules will shadow the stdlib version.
