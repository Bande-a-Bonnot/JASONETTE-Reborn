---
id: "019e8701-5e2d-754b-8773-ea4754591be8"
status: complete
priority: p2
issue_id: "052"
tags: [ios, actions, snapshot, sharing, jasonpedia]
dependencies: []
---

# Implement iOS `$snapshot` action

## Problem Statement

The iOS handoff Phase B action gap still listed `$snapshot` as a missing native action. Jasonpedia's Core → Snapshot demo, Background demo, and Weather/Pokémon layer demos use `$snapshot` followed by `$util.share` with `{{$jason.data}}`. Before this work, `$snapshot` was unrecognized/unsupported and those success chains could not receive image data.

## Fix

- Added `SnapshotResult` and an injectable `ActionDispatcher` snapshot handler seam.
- Implemented `$snapshot` dispatch to call the native handler, store a payload in local state, mirror it under `$jason`, and return it into success chains.
- Snapshot payload shape:
  - `data`: base64-encoded PNG image bytes
  - `media_type`: `image`
  - `content_type`: `image/png`
- Installed an iOS native handler in `JasonetteView`/`MediaPresentation` that captures the current key window using `UIGraphicsImageRenderer` + `drawHierarchy(in:afterScreenUpdates:)`, preserving the currently rendered UI rather than reconstructing the JSON view.
- `$snapshot` failure routes through the existing action error branch; platforms without a native handler show a clear fallback alert.

## Acceptance Criteria

- [x] `$snapshot` calls an injectable native capture handler.
- [x] Successful captures expose base64 image data as `{{$jason.data}}` for chained `$util.share` actions.
- [x] The payload is stored in local state with image/content-type metadata.
- [x] Snapshot failures run the action `error` branch.
- [x] Targeted iOS action tests pass.

## Verification

- Red targeted test first: `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testSnapshot` failed before implementation because `SnapshotResult`, `setSnapshotHandler`, and `snapshotUnavailable` did not exist.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testSnapshot` — 3 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests` — 56 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 539 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `npm run lint:md` — 0 errors.

## Notes

Simulator visual QA was not run in this session; coverage is at the action dispatch/native-handler build level.
