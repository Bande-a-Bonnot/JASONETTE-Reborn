---
id: "019f2ece-a72e-777b-8081-edbc863d8b17"
status: complete
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

## Progress Notes

2026-07-04 partial baseline slice:

- Added Android `ActionDispatcher` callbacks for `$render`, `$reload`, `$href`,
  and named `trigger` resolution through the active document actions map.
- Changed `$network.request` to store a structured `$response` payload instead
  of flattening object fields into local state.
- Added relative URL resolution and http/https scheme guards for `$href` and
  component `href` dispatch through `JasonetteViewModel`.
- Added render-context exposure for `$jason`, `$get`, `$cache`, and `$response`,
  and re-render after handled actions except `$reload`.
- Added baseline footer tab/input rendering and explicit HTML placeholder path;
  map remains an explicit placeholder.
- Added focused unit coverage for dispatcher render/reload callbacks,
  structured `$response`, `$href` safety/resolution, named trigger resolution,
  and footer input decoding.

2026-07-04 fixture-smoke completion slice:

- Extracted Android document template rendering into `JasonetteDocumentRenderer`
  so render-context behavior is testable without a device/Robolectric.
- Added render-context regression coverage for `$jason`, `$get`, and structured
  `$response` without overwriting unrelated state.
- Added Jasonpedia `$network` fixture smoke proving response item fields render
  through `{{#each $response}}` as legacy templates expect.
- Added `#each` item-context precedence coverage: item fields shadow parent
  names, while `$jason`, `$index`, and `$root` are restored after item merging.
- Added footer rendering tests for legacy image/text/url tab shapes, text-only
  footer tab navigation, authored href preservation, and Jasonpedia footer input
  control type inference.
- Footer tabs now convert legacy item `url` into safe navigation `href` while
  preserving icon display URL semantics.

This completes the P1 Android runtime baseline acceptance criteria. Deeper native
map/html parity, richer Android navigation stacks, and UI-level Compose/simulator
coverage remain future parity work rather than this baseline todo.

## Verification

Requires Java 17 locally or CI Android job:

```bash
cd JASONETTE-Android/JasonetteApp
./gradlew test
./gradlew assembleDebug
```

Current local environment note: `java -version` and `./gradlew test --no-daemon`
still fail with `Unable to locate a Java Runtime`; use GitHub Actions for Android
verification until Java is available locally.

- GitHub CI run `28721345742` passed for exact commit `54d8ee6` after the first
  Android baseline implementation slice.
- GitHub CI run `28722041590` passed for exact commit `8d58c31` after the
  fixture-smoke completion slice.
