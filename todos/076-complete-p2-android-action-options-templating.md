---
id: "019f106d-9a54-72dd-96f8-b2aaf2bb8f1d"
status: completed
priority: p2
issue_id: "076"
tags: [android, parity, actions, templates]
dependencies: ["068"]
completed_at: "2026-07-05"
---

# Complete Android action option templating baseline

## Outcome

Android action execution now templates action `options` before dispatching to
handlers. The action context exposes local state as top-level values and `$get`,
cache values as `$cache`, `$response` when present, and a `$jason` fallback to
current local state.

This gives Android the same baseline behavior expected by Jasonette action
fixtures where `$set`, `$href`, `$network.request`, and other option-consuming
actions interpolate values before execution.

## Verification

Added `ActionDispatcherTest` coverage for:

- `$set` options templated from `$get` and `$response`.
- `$set` stores whole-expression arrays/objects without stringification and
  preserves untemplated string, number, boolean, and null values.
- `$cache.set` option templating path is exercised without crashing when cache
  storage is unavailable in JVM tests.
- `$network.request` URL templating before the network handler runs.
- Nested action option arrays/objects templated before handler execution.
- Whole-expression object/array option payloads survive without stringification.
- Untemplated nested primitive option values preserved through the templating pass.
- Existing `JsonElement` values are preserved by `JsonValueConverter.anyToJsonElement`.
- `$href` URL templating before relative URL resolution and navigation dispatch.
- Templated unsafe `$href` URLs still blocked after interpolation.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --no-daemon` fails before Gradle starts with
`Unable to locate a Java Runtime`. Verification should rely on the GitHub Actions
Android job, which provisions Java 17 and runs Gradle tests.
