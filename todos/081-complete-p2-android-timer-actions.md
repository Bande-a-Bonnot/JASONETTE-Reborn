---
id: "019f3044-2865-7da7-8a54-def11c22f5fd"
status: completed
priority: p2
issue_id: "081"
tags: [android, parity, actions, timer]
dependencies: ["068", "076", "080"]
completed_at: "2026-07-05"
---

# Complete Android `$timer.start` / `$timer.stop` action baseline

## Outcome

Android now recognizes the baseline legacy timer action family used by Jasonpedia
Stopwatch/Mario/Vision fixtures and the legacy Android `JasonTimerAction`:

- `$timer.start` reads templated `name`, `interval`, optional `repeats`, and a
  nested `action` object from action options.
- `repeats` defaults to `true` to match the current Jasonette spec/iOS behavior;
  authored `repeats: false` schedules a one-shot timer.
- Repeating timers fire immediately on the ViewModel scope and then wait the
  authored interval, matching the legacy Android handler timing while keeping
  callbacks lifecycle-bound.
- One-shot timers wait the authored interval before firing.
- `$timer.stop` cancels a named timer when `options.name` is present, or all
  timers when it is absent.
- Timer callbacks execute through the normal `ActionDispatcher.execute` path, so
  named triggers, option templating, render chains, and success/error behavior
  remain shared with other actions.
- Timer scheduling is behind `JasonTimerScheduler`, with a ViewModel-scope
  coroutine-backed production scheduler and a deterministic fake scheduler for
  JVM tests.

This is a runtime/action baseline. ViewModel teardown cancels active timers, but
full native background/foreground timer semantics remain future work.

## Verification

Added `ActionDispatcherTest` coverage for:

- `$timer.start` templating the timer name, scheduling interval/repeat metadata,
  continuing success chains, and executing a scheduled named-trigger action.
- Default repeat behavior, explicit one-shot interval conversion, and invalid
  interval error routing.
- `$timer.stop` canceling named and all timers while continuing success chains.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.ActionDispatcherTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`. Verification should rely on the GitHub
Actions Android job, which provisions Java 17 and runs Gradle tests.
