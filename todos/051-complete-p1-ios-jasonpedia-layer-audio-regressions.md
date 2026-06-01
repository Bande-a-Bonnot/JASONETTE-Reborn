---
status: complete
priority: p1
issue_id: "051"
tags: [ios, jasonpedia, actions, layers, audio]
dependencies: []
---

# Fix Jasonpedia layer and audio demo regressions

## Problem Statement

The Jasonpedia static layer `1UP` button and Mario image button demo used `$audio.play`, which was still unimplemented on iOS. The Dynamic Layers fixture rendered empty because templates referenced `{{$get.style}}`, but the ViewModel render context did not expose `$get`; subsequent dynamic layer button actions also used a legacy Jasonette mutation expression that the modern expression parser did not recognize.

## Fix

- Implemented `$audio.play` in `ActionDispatcher` with URL resolution, scheme validation, an injectable test seam, and retained `AVPlayer` playback.
- Added `$get` and `$cache` aliases to the ViewModel template render context.
- Rendered `$set` option values through the template engine so action options can use state expressions.
- Added narrowly-scoped compatibility for the legacy `var new_style = $get.style; new_style['move']='true'; return new_style;` expression form used by the dynamic layer fixture.
- Decoded `body.style`, including `style.background`, and rendered body color/image backgrounds.
- Added `move`, `resize`, and `rotate` style flags plus SwiftUI drag, magnification, and rotation gestures for dynamic layers.

## Acceptance Criteria

- [x] Static layer `1UP` and Mario image-button `$audio.play` actions dispatch to audio playback.
- [x] Dynamic Layers renders its initial layers, including Mario.
- [x] Dynamic layer named actions keep Mario's style renderable and set movement/resize/rotate flags.
- [x] Body `style.background` is decoded for Jasonpedia layer/background fixtures.
- [x] Full iOS test suite passes.

## Verification

- Red targeted tests first for audio handler, `$set` templating, dynamic layer fixture rendering, and dynamic layer trigger style preservation.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 519 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build`.
- `jq empty Jasonpedia/view/layer/dynamic.json Jasonpedia/view/layer/static.json Jasonpedia/view/component/button/3.json`.
- `npm run lint:md`.

## Git Evidence

- Implementation commit: `0c9fb07 fix(ios): repair Jasonpedia layer audio demos`.
- Pushed to `origin/main` on 2026-06-01.
