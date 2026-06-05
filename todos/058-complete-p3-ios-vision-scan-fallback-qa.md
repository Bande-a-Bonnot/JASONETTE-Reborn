---
id: "019e947d-d661-70de-a7ff-6820771a871e"
status: complete
priority: p3
issue_id: "058"
tags: [ios, actions, vision, fallback, qa]
dependencies: []
---

# Verify iOS `$vision.scan` fallback is user-visible

## Problem Statement

The delegated iOS action-screen QA pass on 2026-06-03 found that the direct
`Jasonpedia/action/vision/index.json` fixture stayed on `Scanning...`; no
recognized fallback alert was observed after launch/waiting.

## Root Cause

The fixture does not dispatch `$vision.scan` directly from `$load`. Its flow is:

1. `$load` sets `content` to `Scanning...` and renders the body template.
2. The rendered body declares `background: { "type": "camera" }`.
3. The fixture expects a camera-background implementation to fire
   `$vision.ready`, which then triggers named action `qr`.
4. `qr` is the first action that dispatches `$vision.scan`.

The iOS renderer recognized `$vision.scan` once dispatched, but it did not
implement the live camera background or fire `$vision.ready`, so the fixture
remained at `Scanning...` without user-visible unsupported-state feedback.

## Fix

- Kept direct `$vision.scan` recognized as an explicit fallback alert.
- Added ViewModel detection for rendered camera backgrounds coupled to vision
  lifecycle actions (`$vision.ready`, `$vision.onscan`, or `$vision.scan`).
- Shows a user-visible unsupported-state alert explaining that live
  camera-backed vision scanning is recognized but not implemented.
- De-duplicates the unsupported background alert per rendered document signature,
  rather than globally across the ViewModel lifetime.
- Added Jasonpedia fixture regression coverage proving the direct vision fixture
  renders `Scanning...` and also exposes the unsupported camera/vision fallback.

## Acceptance Criteria

- [x] Direct vision fixture behavior is understood and documented.
- [x] Unsupported `$vision.scan` and camera-backed vision setup do not appear as
      silent no-ops in Jasonpedia.
- [x] Added regression coverage for direct `$vision.scan` fallback and the
      camera-background unsupported path.
- [x] Ran targeted action tests and full `swift test`.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testVisionScan` — 1 test, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ViewModelTests/testJasonpediaVision` — 1 test, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 554 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `npm run lint:md` — 0 errors.

## Notes

Live direct-entry Simulator visual QA was not repeated in this session because
local CoreSimulator had become unreliable during earlier verification: the iPhone
17 Pro simulator hung at `Waiting on System App`, and an already-booted SE
simulator timed out during simctl install/launch. The unsupported fixture path is
covered at the Jasonpedia ViewModel fixture layer.
