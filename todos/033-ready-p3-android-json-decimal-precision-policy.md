---
status: ready
priority: p3
issue_id: "033"
tags: [android, kotlin, json, tests, precision, code-review]
dependencies: []
---

# Define Android JSON decimal/exponent precision policy

## Problem Statement

PR #23 preserves oversized **plain integer** JSON tokens in the Android shared
fixture parser and production `JasonetteViewModel` converter by returning the
original string when a token does not fit in `Int` or `Long`. Decimal and
exponent-shaped numbers still parse through `Double`.

Gemini flagged that very high-precision decimal strings can still lose precision
when converted to `Double`. That is correct, but broader than PR #23's scoped
fix: PR #23 closes the regression where integer-looking values larger than
`Long.MAX_VALUE` silently rounded after the Kotlin accessor compile fix.

## Findings

- Current policy after PR #23:
  - plain integer -> `Int`, then `Long`, else exact `String`
  - decimal/exponent -> `Double` when parseable, else `String`
- This matches the documented PR #23 scope and keeps existing decimal fixture
  behavior stable.
- A full arbitrary-precision policy would need decisions about whether Android
  should use `BigDecimal`, preserve all decimal/exponent tokens as strings, or
  align with iOS/Swift decoding behavior some other way.

## Recommended Action

1. Audit shared fixtures and production Jasonette expectations for high-precision
   decimal or exponent values.
2. Decide the cross-platform contract for decimal/exponent JSON numbers:
   - preserve exact text as `String`,
   - use `BigDecimal`/platform equivalent, or
   - explicitly accept `Double` precision for those shapes.
3. Apply the chosen policy consistently to:
   - `CrossPlatformTest.kt` fixture conversion,
   - `JasonetteViewModel.kt` production conversion,
   - any iOS fixture conversion helpers if applicable.
4. Add regression tests for long decimals and exponent values if exactness is
   required.

## Acceptance Criteria

- [ ] Decimal/exponent JSON number policy is explicitly documented
- [ ] Android test helper and production converter use the same policy
- [ ] Cross-platform expectations are checked before changing existing behavior
- [ ] Regression tests cover at least one high-precision decimal and one exponent
      value, or document why `Double` precision is accepted

## Notes

Source: Gemini review on PR #23 (2026-04-26). Deferred because PR #23 is about
restoring Android CI, preserving oversized plain integers, and aligning the
production converter with that integer policy. Changing decimal/exponent
semantics may affect existing fixtures and renderer behavior and deserves its
own review.
