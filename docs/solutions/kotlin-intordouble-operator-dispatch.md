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
