---
status: complete
priority: p2
issue_id: "028"
tags: [android, ci, tests]
dependencies: []
---

# Android Kotlin test suite fails to compile (pre-existing)

## Problem Statement

The `android` CI job has been red on every PR since at least PR #19
(merged). It fails at `:app:compileDebugUnitTestKotlin` with:

```
CrossPlatformTest.kt:48:65 Unresolved reference 'double'.
CrossPlatformTest.kt:49:30 Unresolved reference 'int'.
StyleModifierTest.kt:20:39 Unresolved reference 'floatOrNull'.
StyleModifierTest.kt:40:40 Unresolved reference 'floatOrNull'.
StyleModifierTest.kt:59:43 Unresolved reference 'floatOrNull'.
StyleModifierTest.kt:76:44 Unresolved reference 'floatOrNull'.
StyleModifierTest.kt:78:41 Unresolved reference 'floatOrNull'.
```

These look like a Kotlin / kotlinx-serialization API drift:
`JsonPrimitive.double` / `.int` / `.floatOrNull` are currently the
extension accessors, and either the import isn't present in those
files or the version of `kotlinx-serialization-json` in use removed
them. Either way the tests can't compile — `swift test` is green but
Android CI is red on every PR including merged ones.

## Findings

- Job: `android` in `.github/workflows/ci.yml` runs on every PR
  (`|| github.event_name == 'pull_request'`) but is not path-filtered
  to Android changes, so even iOS-only or docs-only PRs trip it
- Last green main run (24605619138, 2026-04-18) skipped `android`
  because no Android paths changed and the workflow gating made it a
  no-op on non-android commits that reach main — but any PR targeting
  main reruns it
- Not blocking PR #20 (iOS + docs only); called out in that PR thread

## Recommended Action

1. Add the missing imports to the two test files, e.g.
   `import kotlinx.serialization.json.double`,
   `import kotlinx.serialization.json.int`,
   `import kotlinx.serialization.json.floatOrNull`.
2. If the accessors genuinely no longer exist, pin
   `kotlinx-serialization-json` to the version that does, or
   rewrite the assertions to use `.content.toDouble()` /
   `.content.toIntOrNull()` etc.
3. Verify locally with `./gradlew :app:compileDebugUnitTestKotlin`
   before pushing.
4. Consider path-filtering the `android` job (mirror `ios`) so unrelated
   PRs don't burn CI minutes.

## Acceptance Criteria

- [x] `:app:compileDebugUnitTestKotlin` succeeds on CI
- [x] `android` CI job goes green on a non-Android-change PR
- [x] Tests in `CrossPlatformTest.kt` and `StyleModifierTest.kt` run

## Notes

Completed in PR #21, squash `92e65dd` (2026-04-26). The `pull_request` Android job ran and passed on PR #21 before merge, then ran and passed again on non-Android-change PR #22 before merge because the workflow runs Android on every PR. Local Gradle verification was blocked by this environment having no Java runtime.

Source: noticed while addressing PR #20 review feedback (2026-04-19).
The workflow gating pattern is `if: needs.changes.outputs.android ==
'true' || github.event_name == 'pull_request'` — identical to `ios`
but Android test coverage is clearly not being exercised on main, so
the regression went unnoticed.
