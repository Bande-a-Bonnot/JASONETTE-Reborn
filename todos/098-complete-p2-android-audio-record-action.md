---
id: "019f43d7-02b2-7901-b728-f0a5c7a939dc"
status: completed
priority: p2
issue_id: "098"
tags: [android, parity, actions, audio, record]
dependencies: ["068", "083", "088", "090", "091"]
completed_at: "2026-07-08"
---

# Complete Android `$audio.record` action baseline

## Outcome

Android now recognizes `$audio.record` in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$audio.record` through an injectable audio
  recorder seam instead of treating it as an unknown action.
- Authored `options.color` is templated and defaults to the legacy Android
  overlay color `rgba(0,0,0,0.8)`.
- Successful recordings store the legacy Android payload keys
  `{ file_url, url, content_type, data_uri }` in top-level local state and
  `$jason`; `content_type` is `audio/m4a`.
- Missing handlers, user cancellation, permission denial, startup failures,
  short/invalid stop failures, and thrown native errors route authored `error`
  chains instead of leaking stale success data.
- Error/cancel paths clear stale top-level audio payload keys to empty strings
  and replace `$jason` with either `{}` or `{ message }`.
- `JasonetteViewModel` exposes native audio-record requests with UUIDv7 request
  IDs and request-owned output paths.
- `JasonetteScreen` declares and requests `RECORD_AUDIO`, starts/stops a
  platform `MediaRecorder` session, provides a minimal recording dialog with
  stop/cancel actions, and completes/cancels only the active request.
- Production recording uses app-specific external files and emits a `file://`
  URL plus base64 `data:audio/m4a` payload for legacy compatibility.
- `networkClient` remains the final `ActionDispatcher` constructor parameter,
  preserving existing trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline recorder implementation. It does not attempt to replicate the
legacy third-party recorder UI beyond honoring the color metadata in the minimal
recording dialog.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$audio.record` success payloads, templated color options, legacy payload keys,
  top-level local state, `$jason`, and success-chain access through
  `{{$jason.file_url}}`.
- Default color and asynchronous recorder completion so success chains wait for
  native completion.
- Missing handler, cancellation, and thrown native errors routing authored
  `error` branches while clearing stale audio payload keys.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared current
Android, legacy Android `JasonAudioAction`, current iOS semantics, and Jasonpedia
usage. Dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer passes caught and
helped address stop-failure success, dispose hangs, stale payload leakage,
permission-path, temp-file cleanup, async-test, and untracked helper-file risks
before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests com.jasonette.ActionDispatcherTest
--no-daemon` fails before Gradle starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28979801451` passed for exact implementation head SHA
`fdca6c413dc5dbed2b9931d94952c31a1ee12d71`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully.
