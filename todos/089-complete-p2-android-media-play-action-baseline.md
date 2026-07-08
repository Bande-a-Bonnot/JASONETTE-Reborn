---
id: "019f42d6-4132-7245-beb2-a962c5dc792a"
status: completed
priority: p2
issue_id: "089"
tags: [android, parity, actions, media, video]
dependencies: ["068", "076", "083", "088"]
completed_at: "2026-07-08"
---

# Complete Android `$media.play` action baseline

## Outcome

Android now recognizes the Jasonpedia/legacy `$media.play` video action in the
built `JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$media.play`, templates options through the
  existing action-option rendering path, resolves relative URLs against the
  active document URL, and blocks non-HTTP(S) schemes via the shared URL guard.
- `AndroidMediaPlayback` launches an Android `ACTION_VIEW` intent with the
  legacy-compatible `video/mp4` MIME type.
- `JasonetteViewModel` wires real JSON action dispatch to the production media
  playback launcher.
- Normal success chains run after the external activity launch succeeds; authored
  error chains run for missing URLs, blocked schemes, or launch failures.

This is a baseline only. Legacy Android resumed success after the external
player returned through `dispatchIntent`, while this Compose baseline reports
success after launch. Richer lifecycle/dismissal semantics and broader media MIME
handling remain future parity work.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$media.play` resolving a relative URL and running the success chain.
- Blocking disallowed schemes before invoking playback and running the error
  branch.
- Playback-provider failure routing to an authored error branch.
- Missing URL error routing.

A read-only reviewer subagent checked the uncommitted implementation for compile
risk, constructor/trailing-lambda compatibility, production reachability,
URL/security semantics, intent lifecycle concerns, and parity limits. It found no
critical issues and confirmed existing trailing-lambda `networkClient` call sites
still bind to the final constructor parameter.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.ActionDispatcherTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28958731704` passed for exact head SHA
`7b614aeb358b05393ada9eeb6c124785f01d84ec`. Its Android job provisioned Java 17
and completed successfully.
