---
id: "019f4268-2a74-773d-a4cb-008bcd4bba97"
status: completed
priority: p2
issue_id: "088"
tags: [android, parity, actions, audio, media]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-08"
---

# Complete Android `$audio.play` action baseline

## Outcome

Android now recognizes the Jasonpedia/legacy `$audio.play` action in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$audio.play`, templates options through the
  existing action-option rendering path, resolves relative URLs against the
  active document URL, and blocks non-HTTP(S) schemes via the shared URL guard.
- A production `AndroidAudioPlayer` uses `MediaPlayer` with media audio
  attributes, starts after async preparation succeeds, releases superseded
  players, and propagates setup/prepare/start failures back to dispatcher error
  chains.
- `JasonetteViewModel` wires real JSON action dispatch to the production audio
  player and releases the player on `onCleared()`.
- Normal success chains run after playback preparation/start succeeds; authored
  error chains run for missing URLs, blocked schemes, or playback-provider
  failures.

This is a baseline only. Legacy Android also exposed `$audio.pause`,
`$audio.stop`, `$audio.duration`, `$audio.position`, `$audio.seek`, and
`$audio.record`; those remain future parity work. `$media.play` video/native UI
parity is also a separate remaining action family.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$audio.play` resolving a relative URL and running the success chain.
- Blocking disallowed schemes before invoking the player and running the error
  branch.
- Missing URL error routing.
- Playback-provider failure routing to an authored error branch.

A read-only reviewer subagent checked the uncommitted implementation for compile
risk, constructor/trailing-lambda compatibility, production reachability,
URL/security semantics, MediaPlayer lifecycle, and parity limits. It found no
critical issues. Its async playback/lifecycle warnings were addressed before
commit by awaiting prepare/start, releasing failed/superseded players, guarding
stale callbacks, and propagating errors.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.ActionDispatcherTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28751355872` passed for exact head SHA
`8f0739817104750ae8e37f97b75ea3e745ee47f5`. Its Android job provisioned Java 17
and completed successfully.
