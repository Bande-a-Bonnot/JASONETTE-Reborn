---
id: "019f2ece-a72e-777b-8081-edbc863d8b17"
status: open
priority: p1
issue_id: "068"
tags: [android, parity, actions, rendering, navigation]
dependencies: []
---

# Android runtime parity baseline

## Problem Statement

The current Android implementation is a compact Jetpack Compose renderer with
core document/template/state tests, but it is much narrower than legacy Android
and current iOS. The parity audit found the first high-value Android gap is not
native media; it is runtime/action/navigation/render-context behavior.

Current `ActionDispatcher.kt` implements only `$set`, cache basics, no-op
`$render`/`$reload`, and minimal `$network.request`. `JasonetteScreen.kt` can
render sections and layers but does not yet provide a full navigation/action
runtime baseline.

See `docs/research/2026-07-04-cross-platform-parity-audit.md`.

## Acceptance Criteria

- `$render` can trigger a ViewModel re-render after `$set` or success-chain
  payload changes.
- `$network.request` stores a structured `$response` payload and exposes it to
  success chains/templates without overwriting unrelated state.
- `$href` is decoded/executed through a safe navigation abstraction with relative
  URL resolution and scheme guards.
- Footer tabs/input rendering has a baseline implementation or explicit tested
  fallback behavior.
- Map/html unsupported paths have clear visible placeholders and tests, pending
  later native parity work.
- Add targeted unit tests for action dispatch, ViewModel render context, URL
  safety, footer decode/render, and at least one Jasonpedia fixture smoke.

## Suggested Files

- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/rendering/ActionDispatcher.kt`
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/rendering/JasonetteViewModel.kt`
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/rendering/JasonetteScreen.kt`
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/core/JasonDocument.kt`
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/components/ComponentView.kt`
- `JASONETTE-Android/JasonetteApp/app/src/test/java/com/jasonette/`

## Verification

Requires Java 17 locally or CI Android job:

```bash
cd JASONETTE-Android/JasonetteApp
./gradlew test
./gradlew assembleDebug
```

Current local environment note: `java -version` still fails with `Unable to
locate a Java Runtime`; use GitHub Actions for Android verification until Java is
available locally.
