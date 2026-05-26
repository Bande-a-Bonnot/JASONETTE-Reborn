---
title: "Android JSON decimal and exponent numbers use Double by policy"
date: 2026-05-26
category: build-errors
module: JASONETTE-Android
problem_type: precision_policy
component: json_bridge
symptoms:
  - "Plain oversized integers were fixed to preserve exact text"
  - "High-precision decimal and exponent JSON numbers still round through Double"
root_cause: explicit_contract
resolution_type: policy_documentation
severity: low
tags: [android, kotlin, kotlinx-serialization, json, precision, decimals, tests]
---

# Android JSON Decimal and Exponent Numbers Use Double by Policy

## Problem

After the Android JSON bridge was fixed to preserve oversized plain integers as
strings, review correctly noted that high-precision decimal and exponent-shaped
numbers can still lose precision when converted to `Double`.

That is true, but it is a broader semantic contract than the plain-integer bug.
The renderer and template engine currently treat decimal/exponent numbers as
native floating-point values.

## Current Contract

`JsonValueConverter` centralizes the Android bridge from
`kotlinx.serialization` `JsonElement` values to the plain Kotlin values consumed
by templates and rendering:

- JSON strings stay `String`.
- `true`, `false`, and `null` map to `Boolean` / `null`.
- Plain integer-shaped numbers parse as `Int`, then `Long`; values outside
  `Long` range preserve the exact token text as `String`.
- Decimal or exponent-shaped numbers parse as `Double` when possible; if parsing
  fails, the token text is preserved as `String`.

This means arbitrary-precision decimal/exponent exactness is **not** guaranteed
today. Precision loss for values such as
`0.123456789012345678901234567890` is accepted under the current Android
contract.

## Why Keep Double for Now

- Existing Android template expression helpers operate on `Double` for floating
  arithmetic (`Math.*`, division, modulo, comparisons, `Number`, `parseFloat`).
- Existing shared expression fixtures expect `Double` for decimal results.
- iOS `AnyCodable` also decodes JSON decimal/exponent-shaped numbers as `Double`
  today, so preserving them as strings only on Android would create a new
  cross-platform divergence.
- Exact decimal support would require a broader product decision: preserve all
  decimals as strings, introduce `BigDecimal`/platform equivalents, or define
  typed numeric wrappers across renderers.

## Implementation Pattern

Do not duplicate ad hoc fixture and production converters. Production rendering
and cross-platform tests should both call `JsonValueConverter` so the policy
cannot drift:

```kotlin
val data = head?.data?.entries?.associate { (key, value) ->
    key to JsonValueConverter.jsonElementToAny(value)
}
```

Tests should lock both parts of the policy:

- oversized plain integers remain exact strings;
- high-precision decimal and exponent values are intentionally `Double`.

## Future Change Criteria

Change this policy only with a cross-platform decision. If exact
decimal/exponent values become required, update:

1. Android `JsonValueConverter`;
2. Android fixture and production rendering call sites;
3. iOS `AnyCodable` / fixture conversion expectations;
4. shared fixtures documenting exact decimal/exponent semantics;
5. template expression arithmetic rules for string/decimal inputs.

## Related Issues

- `todos/033` — define Android JSON decimal/exponent precision policy.
- [`kotlinx-json-numeric-accessors-android-test-compile.md`](kotlinx-json-numeric-accessors-android-test-compile.md)
  — the preceding Android JSON numeric accessor and oversized-integer fix.
