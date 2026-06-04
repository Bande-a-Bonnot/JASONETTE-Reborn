---
id: "019e947d-2d90-7347-ac74-de1839c3c0fc"
status: complete
priority: p2
issue_id: "055"
tags: [ios, actions, toast, banner, ui, jasonpedia]
dependencies: []
---

# Render `$util.toast` and `$util.banner` as transient UI

## Problem Statement

`$util.toast` and `$util.banner` were implemented as alert fallbacks. That made
Jasonpedia action demos modal and blocking instead of showing non-blocking toast
or banner notifications.

## Fix

- Added a dedicated `UtilityNotificationRequest` action-dispatch path separate
  from `$util.alert`.
- Routed `$util.toast` to a bottom transient capsule notification.
- Routed `$util.banner` to a top transient full-width banner notification.
- Preserved templating of authored `text`, `title`, and `description` options.
- Added support for authored notification `type` values such as `success`,
  `error`, `warning`, `info`, and `dark` for basic coloring/icons.
- Added automatic dismissal after roughly 2 seconds.

## Acceptance Criteria

- [x] `$util.toast` does not present a modal alert in normal iOS rendering.
- [x] `$util.banner` does not present a modal alert in normal iOS rendering.
- [x] Toast appears near the bottom of the document surface.
- [x] Banner appears near the top of the document surface.
- [x] Notifications do not block interaction and auto-dismiss.
- [x] Existing action success chaining remains unchanged.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testUtil --filter ViewModelTests/testToast --filter ViewModelTests/testBanner` — 7 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 547 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `npm run lint:md` — 0 errors.

## Notes

No simulator visual QA was run for this fix in this session; coverage is at the
action-dispatch/view-model/native SwiftUI build level.
