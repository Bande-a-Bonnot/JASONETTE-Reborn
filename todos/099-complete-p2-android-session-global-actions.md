---
id: "019f47ba-e977-7be9-a9b2-91a5172eb460"
status: completed
priority: p2
issue_id: "099"
tags: [android, parity, actions, session, global, network]
dependencies: ["068", "076"]
completed_at: "2026-07-09"
---

# Complete Android `$session` / `$global` action baseline

## Outcome

Android now recognizes `$session.set`, `$session.reset`, `$global.set`, and
`$global.reset` in the built `JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$global.set` and `$global.reset` instead of
  treating them as unknown success no-ops.
- `$global.set` persists structured option values in a dedicated global store,
  returns the full updated global object under `$jason`, and exposes `$global`
  to action/template contexts.
- `$global.reset` removes only listed `options.items` keys and returns the full
  updated global object under `$jason`.
- Missing or malformed `$global` options abort without running success/error
  continuations, matching legacy fail-soft behavior.
- `StateManager` keeps `$global` separate from local/cache state and backs it
  with the legacy Android `SharedPreferences("global")` store when an Android
  context is available.
- `ActionDispatcher` dispatches `$session.set` and `$session.reset` instead of
  treating them as unknown success no-ops.
- `$session.set` normalizes `domain` or `url` to a lowercase host, stores the
  authored session options in a dedicated session store, and exposes success
  payload `{}` under `$jason`.
- `$session.reset` removes the normalized domain session and exposes success
  payload `{}` under `$jason`.
- Missing `$session` domain/url aborts without success/error continuations,
  matching legacy Android behavior.
- `$network.request` decorates requests for matching domains with session
  headers and body parameters; session body values append to GET query strings
  and merge into non-GET form data, with authored header/data values winning on
  key conflicts.
- Production `HttpURLConnection` requests now consume decorated `header` and
  `data` options, including setting `doOutput = true` before writing non-GET
  form bodies.
- `networkClient` remains the final `ActionDispatcher` constructor parameter,
  preserving existing trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline legacy runtime implementation. It does not implement richer
cookie/html-session handling beyond the legacy action stores and network request
header/body decoration.

## Verification

Added JVM coverage for:

- `$global.set` structured payload storage, `$jason` return payloads, and
  `$global` template access from success chains.
- `$global.reset` removing only listed keys and returning the updated payload.
- Missing/malformed `$global` options aborting without success/error chains.
- `$session.set` normalizing domain/url, decorating GET requests with session
  headers and query parameters, and `$session.reset` removing the session.
- `$session.set` missing domain/url aborting without success/error chains.
- Session/body/header merge semantics for non-GET requests, including authored
  header/data precedence over session values.
- `StateManager` maintaining separate global/session stores in memory.
- `JasonetteDocumentRenderer` exposing `$global` to templates.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared current
Android with legacy Android `JasonSessionAction`, `JasonGlobalAction`, and
`JasonNetworkAction`. Dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer passes
caught and helped address cross-screen SharedPreferences visibility, stale
session reset behavior, production HTTP header/data consumption, and
missing-option no-op semantics before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests com.jasonette.ActionDispatcherTest
--tests com.jasonette.StateManagerTest --tests
com.jasonette.JasonetteDocumentRendererTest --no-daemon` fails before Gradle
starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `29001193565` passed for exact implementation head SHA
`e96edec89bba50879702bc1d88a2f36d436e5b1c`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully.
