---
id: "019f43b2-d50e-72f8-801c-6f67f14159d6"
status: completed
priority: p2
issue_id: "097"
tags: [android, parity, actions, media, camera, picker]
dependencies: ["068", "083", "092"]
completed_at: "2026-07-08"
---

# Complete Android `$media.camera` / `$media.picker` action baseline

## Outcome

Android now recognizes `$media.camera` and `$media.picker` in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches both actions through an injectable media-capture
  seam instead of treating them as unknown actions that incorrectly continue as
  success.
- `options.type` is templated and selects `image` by default or `video` when the
  option is `"video"`.
- `$media.camera` captures request metadata for `source: "camera"`,
  `mediaType`, `edit`, and `quality`.
- `$media.picker` captures request metadata for `source: "picker"` and
  `mediaType`.
- Successful image captures/picks store the legacy Android payload keys
  `{ data, data_uri, content_type }` in top-level local state and `$jason`.
- Successful video captures/picks store the legacy Android payload keys
  `{ file_url, content_type }` in top-level local state and `$jason`.
- Missing handlers, user cancellation, and thrown capture failures route authored
  `error` chains and clear `$jason` to an empty payload so stale prior media data
  does not leak into the error branch.
- `JasonetteViewModel` exposes native media-capture requests with UUIDv7 request
  IDs and camera output URIs owned by the request.
- `JasonetteScreen` registers Activity Result launchers during composition,
  launches system camera/picker contracts when a media request appears, guards
  against relaunching the same pending request after recomposition/configuration
  changes, and completes/cancels only the matching launched request ID.
- Production capture uses system `TakePicture`, `CaptureVideo`, and
  `PickVisualMedia` contracts plus the existing app `FileProvider`; no app-level
  `CAMERA` permission or storage permission is declared for this baseline.
- `networkClient` remains the final `ActionDispatcher` constructor parameter,
  preserving existing trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline media capture/picker implementation. It intentionally does
not implement legacy camera `edit` UI or `quality` handling beyond preserving the
request metadata at the dispatcher seam.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$media.camera` photo requests, templated/default image semantics, `edit` and
  `quality` request metadata, legacy image payload keys, and success-chain access
  through `{{$jason.data}}`.
- `$media.camera` video requests, legacy video payload keys, and success-chain
  access through `{{$jason.file_url}}`.
- `$media.picker` default image requests and templated video requests.
- Unavailable, cancelled, and throwing media-capture paths routing authored
  `error` branches with an empty `$jason` payload instead of stale media data.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared current
Android, legacy Android `JasonMediaAction`, current iOS media semantics, and
Jasonpedia usage. Dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer passes
caught and helped address launch failure suspension, stale callback completion,
configuration-change relaunch, legacy payload-key drift, stale `$jason` error
payloads, and untracked helper-file risks before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests com.jasonette.ActionDispatcherTest
--no-daemon` fails before Gradle starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28977875007` passed for exact implementation head SHA
`17c774bf625601a1058e2452ea115fc888167744`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully.
