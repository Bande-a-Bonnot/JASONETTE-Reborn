---
id: "019e89ef-b675-7868-a456-d44718c7e23e"
status: complete
priority: p2
issue_id: "053"
tags: [ios, actions, media, video, jasonpedia]
dependencies: []
---

# Implement iOS `$media.play` action

## Problem Statement

The iOS handoff Phase B action gap still listed `$media.play` as a recognized fallback alert instead of native playback. Jasonpedia Action → `$media` includes a `$media.play` row with a remote MP4 URL, so the demo should open native video playback rather than showing a not-implemented alert.

## Fix

- Added `MediaPlaybackRequest` and an injectable `ActionDispatcher` media playback handler seam.
- Implemented `$media.play` dispatch with:
  - authored `options.url` parsing
  - relative URL resolution against the current document URL
  - post-resolution `http`/`https` scheme allowlist enforcement
  - native handler invocation
  - failure routing through the existing action `error` branch
- Installed an iOS native handler in `JasonetteView`/`MediaPresentation` that presents `AVPlayerViewController` through a SwiftUI sheet and starts playback automatically.
- The action awaits sheet dismissal before continuing success chains, matching user-visible modal media playback semantics.

## Acceptance Criteria

- [x] `$media.play` resolves relative video URLs against the current document URL.
- [x] Disallowed schemes such as `file:` are blocked before native playback.
- [x] iOS presents a native video player for allowed URLs.
- [x] Handler failures run the action `error` branch.
- [x] Targeted iOS action tests pass.

## Verification

- Red targeted test first: `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testMediaPlay` failed before implementation because `MediaPlaybackRequest`, `setMediaPlaybackHandler`, and `mediaPlaybackUnavailable` did not exist.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testMediaPlay` — 3 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests` — 59 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 542 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `npm run lint:md` — 0 errors.
- Git evidence: committed as `df1661d feat(ios): play media videos natively` and pushed to `origin/main` on 2026-06-02.
- CI evidence: GitHub Actions `CI` run `26845022780` for `df1661d` completed successfully; Pages deployment run `26845017495` completed successfully.

## Notes

Simulator visual QA was not run in this session; coverage is at the action dispatch/native-player build level.
