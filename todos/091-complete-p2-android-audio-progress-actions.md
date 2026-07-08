---
id: "019f42fa-c8af-7a33-ac3a-235f0778b682"
status: completed
priority: p2
issue_id: "091"
tags: [android, parity, actions, audio, media]
dependencies: ["068", "076", "083", "088", "090"]
completed_at: "2026-07-08"
---

# Complete Android `$audio.duration` / `$audio.position` / `$audio.seek` baseline

## Outcome

Android now recognizes the legacy `$audio.duration`, `$audio.position`, and
`$audio.seek` actions in the built `JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches the three progress actions through injectable
  audio progress/control seams while preserving normal continuation behavior.
- `$audio.duration` stores a legacy-compatible string `value` payload in local
  state and `$jason`, using seconds from the underlying player.
- `$audio.position` stores a legacy-compatible string `value` payload in local
  state and `$jason`, using the current-position/duration ratio from the
  underlying player.
- `$audio.seek` accepts the legacy `options.position` ratio and converts it to a
  `MediaPlayer.seekTo()` millisecond offset in production.
- Missing, malformed, unavailable, or throwing seek operations are treated as
  no-op successes, matching the legacy Android action's non-fatal seek behavior.
- Duration/position unavailable paths set a legacy-style `$jason.message` payload
  before routing authored error continuations.
- `JasonetteViewModel` wires the new dispatcher seams to the production
  `AndroidAudioPlayer`; `AndroidAudioPlayer.release()` now also confines release
  work to the main looper.

This is a baseline only. Legacy Android also exposed `$audio.record`, which
remains future audio parity work. Production duration/position provider throws
are currently mapped to payload errors for known `MediaPlayer` state failures;
other unexpected provider exceptions route to error continuations without a
custom payload.

## Verification

Added JVM dispatcher coverage in `ActionDispatcherTest` for:

- `$audio.duration` and `$audio.position` storing `value` payloads and running
  success chains.
- Injected and default unavailable duration/position paths setting
  `$jason.message` and routing error chains.
- `$audio.seek` parsing ratio `position` and running success chains.
- Missing, invalid, unavailable, and throwing seek operations remaining no-op
  successes instead of error branches.

A dedicated read-only reviewer subagent was run with `openai-codex/gpt-5.5` and
`xhigh` thinking as requested by the active parity goal. The first pass caught
legacy mismatches around seek error behavior and duration/position error payloads.
The follow-up pass reported no critical issues after those fixes, confirmed the
new constructor parameters preserve the existing trailing `networkClient`
position, confirmed production wiring, and found no `$media.play`/`Pay` typo or
miswire.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --no-daemon` fails before Gradle starts with
`Unable to locate a Java Runtime`.

GitHub Actions CI run `28965915148` passed for exact implementation head SHA
`6803ea5db2b44addaafd55cf81752eaf8e0b773a`; its Android job provisioned Java 17
and completed successfully.
