---
id: "019f3018-e452-7c9e-ab97-9f33cb3dda4d"
status: completed
priority: p1
issue_id: "079"
tags: [android, parity, navigation, actions]
dependencies: ["068", "073", "076", "078"]
completed_at: "2026-07-05"
---

# Complete Android navigation stack and back/close action baseline

## Outcome

Android now wires the existing `$href` dispatcher path into the app shell instead
of dropping navigation callbacks at `MainActivity`:

- `MainActivity` owns a small Compose URL stack seeded with the hosted demo URL.
- Stack entries use UUIDv7 view-model keys so duplicate URL pushes create
  independent navigation entries instead of sharing one `JasonetteViewModel`.
- `$href` pushes the resolved destination URL onto the stack.
- `$href` with `transition: "replace"` or `view: "replace"` replaces the current
  stack entry with a fresh entry.
- The Android system back button pops in-app navigation when the stack has more
  than one entry.
- `$back` and `$close` actions are recognized by `ActionDispatcher`, continue
  success chains, and call registered app-shell handlers; at the root they finish
  the activity.

This is a baseline navigation parity slice, not a full legacy Android navigation
clone. Richer legacy behavior such as tab switching, preload/fresh handling,
modal/fullscreen semantics, and native controller options remains future work.

## Verification

Added `ActionDispatcherTest` coverage for:

- `$back` and `$close` invoking registered handlers while continuing success
  chains.
- `$close` falling back to the back handler when no dedicated close handler is
  registered.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --no-daemon` fails before Gradle starts with
`Unable to locate a Java Runtime`. Verification should rely on the GitHub Actions
Android job, which provisions Java 17 and runs Gradle tests.
