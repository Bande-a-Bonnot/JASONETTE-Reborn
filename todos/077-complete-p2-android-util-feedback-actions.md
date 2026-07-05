---
id: "019f1078-9492-776d-9a5b-a76a914d6b9d"
status: completed
priority: p2
issue_id: "077"
tags: [android, parity, actions, utility, ui]
dependencies: ["068", "076"]
completed_at: "2026-07-05"
---

# Complete Android utility feedback action baseline

## Outcome

Android now recognizes `$util.alert`, `$util.toast`, and `$util.banner` in the
runtime action dispatcher.

Implemented behavior:

- `ActionDispatcher` emits a typed `UtilityMessage` for alert/toast/banner actions.
- Utility action options are templated by the existing Android action-option
  templating path before dispatch.
- Success chains continue after utility actions, matching the baseline action
  chaining behavior.
- `JasonetteViewModel` exposes utility messages as a buffered event stream and
  installs the dispatcher utility handler so repeated identical messages are not
  suppressed by state equality.
- `JasonetteScreen` renders alerts as Material `AlertDialog` and toast/banner
  feedback as Material snackbar messages.

This is a baseline parity slice for legacy Android `JasonUtilAction` feedback
paths. Richer native picker/datepicker/share/addressbook behaviors remain future
Android parity work.

## Verification

Added `ActionDispatcherTest` coverage for:

- `$util.alert` emitting a templated utility message and running its success chain.
- `$util.toast` emitting a toast utility message.
- `$util.banner` emitting a banner utility message.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --no-daemon` fails before Gradle starts with
`Unable to locate a Java Runtime`. Verification should rely on the GitHub Actions
Android job, which provisions Java 17 and runs Gradle tests.
