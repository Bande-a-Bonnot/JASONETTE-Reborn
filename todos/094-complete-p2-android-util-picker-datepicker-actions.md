---
id: "019f4340-a596-7a92-afd8-122fe53b1f9e"
status: completed
priority: p2
issue_id: "094"
tags: [android, parity, actions, util, picker, datepicker]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-08"
---

# Complete Android `$util.picker` and `$util.datepicker` baselines

## Outcome

Android now recognizes the legacy utility picker/date actions in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$util.picker` through an injectable picker seam
  and `$util.datepicker` through an injectable date picker seam while preserving
  existing `networkClient` trailing-lambda compatibility.
- Picker requests carry authored titles and displayable items. Item parsing
  supports strings plus object items with `text`, `title`, `value`, item-level
  `action`, and item-level `href`.
- Picker selections store `{ index, text, value }` under top-level local state
  and `$jason`, then execute selected item actions or hrefs when authored.
- Picker cancellation/unavailable/invalid selection routes authored `error`
  continuations instead of hanging.
- Datepicker requests optionally carry an initial Unix-second `value` or
  `timestamp`, return numeric Unix seconds under `$jason.value`, and preserve
  success/error continuation behavior.
- `JasonetteViewModel` and `JasonetteScreen` wire the production seams to native
  Compose/Android UI: picker via a Material dialog and date/time selection via
  `DatePickerDialog` followed by `TimePickerDialog`, with cancellation and
  disposal cleanup.
- Android template expression compatibility now handles the Jasonpedia legacy
  date expression `(new Date(parseInt($jason.value) * 1000)).toString()` using
  `Long` math so Unix-second values such as `1700000000` do not overflow before
  date conversion.

This is a baseline, not full legacy parity. Legacy Java `$util.picker` fired its
`success` continuation immediately with an empty payload while separately
broadcasting selected item actions. The current baseline intentionally follows
the modern iOS-style awaited native UI semantics so authored continuations see a
selection payload and cancellation can route an error branch.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- Picker requests receiving authored title/items and storing selected payloads in
  `$jason` plus top-level state for success chains.
- Primitive and title-only picker items.
- Non-contiguous original item indices after skipped unsupported entries.
- Selected item `action` execution and selected item `href` navigation.
- Picker cancellation routing an authored error branch.
- Datepicker initial value propagation, numeric Unix-second payloads, and
  success-chain numeric template flow.
- Datepicker unavailable/cancelled path routing an authored error branch.

Added `TemplateEngineTest` coverage for the Jasonpedia legacy date expression,
including a `1700000000` Unix-second regression that would overflow if evaluated
with `Int` math, and malformed timestamp rendering to an empty string.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared the legacy
Java implementation, current Kotlin renderer, iOS reference todo, and Jasonpedia
fixture before implementation. Dedicated `openai-codex/gpt-5.5` / `xhigh`
review passes found no critical issues; warnings about numeric date payloads,
initial date values, primitive/title picker items, dialog cleanup, and
non-contiguous picker indices were addressed before final validation.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests ... --no-daemon` commands fail before
Gradle starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28970556796` passed for exact implementation head SHA
`fdeeefdbcc621adcdd77bf26022b16cd05242266`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully. Earlier implementation
run `28970353595` failed at SHA `aef4f666d64c8de5b12884411f804d1b8c9d1d25` on a
numeric datepicker template assertion and was fixed by follow-up commit
`fdeeefdbcc621adcdd77bf26022b16cd05242266`.
