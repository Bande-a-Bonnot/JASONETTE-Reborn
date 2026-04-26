---
title: "Kotlinx JSON numeric accessors can break Android test compilation"
date: 2026-04-26
category: build-errors
module: JASONETTE-Android tests
problem_type: build_error
component: testing_framework
symptoms:
  - ":app:compileDebugUnitTestKotlin fails with unresolved JsonPrimitive numeric accessors"
  - "Tests reference JsonPrimitive.double, JsonPrimitive.int, or floatOrNull without resolvable imports"
  - "Naive fallback parsing can silently round oversized integer fixture values"
root_cause: wrong_api
resolution_type: test_fix
severity: medium
tags: [android, kotlin, kotlinx-serialization, json, numeric-parsing, gradle, tests, ci]
---

# Kotlinx JSON Numeric Accessors Can Break Android Test Compilation

## Problem

Android JVM tests failed to compile because test helpers used kotlinx.serialization
JSON numeric extension accessors that were not imported/resolved in the test
files. The first fix restored compilation, but review then caught a second risk:
oversized integer-looking JSON values could fall through to `Double` and lose
precision. That policy had to be aligned in both the test fixture converter and
the analogous production renderer converter.

## Symptoms

- `:app:compileDebugUnitTestKotlin` failed in CI.
- `CrossPlatformTest.kt` reported unresolved references for `double` and `int`.
- `StyleModifierTest.kt` reported unresolved references for `floatOrNull`.
- The Android job was red on pull requests, including unrelated/iOS-only PRs.

## What Didn't Work

- Treating this as only a missing-import problem was incomplete. Importing
  `JsonPrimitive.double` / `int` would compile, but those accessors throw on
  malformed values and the existing dot-based heuristic mishandled scientific
  notation.
- A broad `toIntOrNull() ?: toLongOrNull() ?: toDoubleOrNull()` fallback was
  safer for malformed input, but still allowed integer literals larger than
  `Long.MAX_VALUE` to become imprecise `Double` values.
- Local Gradle verification was not available in this environment because no
  Java runtime was installed; CI had to be the source of truth.

## Solution

Import the JSON classes used throughout the fixture helper and avoid the
unresolved numeric extension accessors in `CrossPlatformTest.kt`:

```kotlin
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
```

Use explicit, shape-aware parsing for JSON primitive fixture values:

```kotlin
private fun jsonElementToAny(element: JsonElement): Any? =
    when (element) {
        is JsonPrimitive -> {
            val content = element.content
            if (element.isString) content
            else if (content == "true") true
            else if (content == "false") false
            else if (content == "null") null
            else if (content.contains('.') || content.contains('e', ignoreCase = true)) {
                content.toDoubleOrNull() ?: content
            } else {
                content.toIntOrNull() ?: content.toLongOrNull() ?: content
            }
        }
        is JsonArray ->
            element.map { jsonElementToAny(it) }
        is JsonObject ->
            element.toMap().mapValues { (_, v) -> jsonElementToAny(v) }
    }
```

Import `floatOrNull` where the style assertions use it:

```kotlin
import kotlinx.serialization.json.floatOrNull
```

Apply the same numeric policy in `JasonetteViewModel.kt` so production rendering
and shared fixture tests do not diverge. Also serialize `Long` values explicitly
in `anyToJsonElement` after the converter starts returning them.

Add a regression test for the precision policy:

```kotlin
@Test
fun testOversizedIntegerFixtureValuePreservesPrecision() {
    assertEquals("9223372036854775808", parseJson("9223372036854775808"))
    assertEquals("-9223372036854775809", parseJson("-9223372036854775809"))
}
```

## Why This Works

The Android tests no longer depend on unresolved `double` / `int` extension
properties, and `floatOrNull` is explicitly imported where used. The fixture and
production render converters now treat number shape as part of the JSON bridge
contract:

- JSON strings stay `String`.
- `true`, `false`, and `null` map to Kotlin primitives/null.
- Decimal or exponent-shaped numbers parse as `Double` when possible.
- Plain integer-shaped numbers parse as `Int`, then `Long`, and otherwise
  preserve their exact text as `String` instead of rounding through `Double`.

For shared cross-platform fixtures, preserving exactness for plain integer
literals is safer than silently coercing them into an imprecise native numeric
type. Decimal/exponent precision needs a separate policy if future fixtures rely
on arbitrary-precision values there.

## Prevention

- Treat test fixture parsers as semantic code, not throwaway plumbing.
- Add sentinel tests whenever numeric conversion rules change.
- Do not fall back from oversized plain integer text to `Double` unless the test
  contract explicitly accepts precision loss.
- Record CI evidence precisely when local verification is blocked by environment
  setup.
- Ensure Android development environments have Java 17 installed before taking
  Android CI work:

```bash
cd JASONETTE-Android/JasonetteApp
./gradlew :app:compileDebugUnitTestKotlin
./gradlew test
```

## Related Issues

- PR #21: fixed the Android Kotlin test compile failure (`92e65dd`).
- PR #23 follow-up: Codex 5.5 xhigh and CodeRabbit review caught oversized-integer precision and test/production parser divergence risks.
- [`../kotlin-json-safe-cast.md`](../kotlin-json-safe-cast.md) — related Kotlin JSON `JsonElement` casting pitfall.
- [`../kotlin-intordouble-operator-dispatch.md`](../kotlin-intordouble-operator-dispatch.md) — related Kotlin numeric type-preservation pitfall.
