---
title: "Safe JsonElement casting in kotlinx.serialization"
category: debugging-patterns
tags: [kotlin, kotlinx-serialization, json, classcastexception]
module: JASONETTE-Android
symptom: "ClassCastException when accessing jsonPrimitive on JsonObject/JsonArray"
root_cause: "Unsafe cast from JsonElement to JsonPrimitive"
---

# Safe JsonElement casting in kotlinx.serialization

## Problem

`element.jsonPrimitive.content` throws `ClassCastException` when `element` is
a `JsonObject` or `JsonArray`, not a `JsonPrimitive`.

## Solution

Use safe cast `as? JsonPrimitive` or a helper function:

```kotlin
private fun jsonElementToString(element: JsonElement): String {
    return when (element) {
        is JsonPrimitive -> element.content
        else -> element.toString()
    }
}
```

## Key Insight

In Jasonette, action options can contain any JSON type — not just strings.
Always handle all `JsonElement` variants when processing dynamic JSON.
