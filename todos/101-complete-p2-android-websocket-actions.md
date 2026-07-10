---
id: "019f4aeb-ddd3-7845-a565-ddbf6c634fcf"
status: completed
priority: p2
issue_id: "101"
tags: [android, parity, actions, websocket]
dependencies: ["068", "083"]
completed_at: "2026-07-10"
---

# Complete Android `$websocket` action baseline

## Outcome

Android now recognizes the legacy `$websocket.open`, `$websocket.send`, and
`$websocket.close` actions in the built `JASONETTE-Android/JasonetteApp`
renderer:

- `ActionDispatcher` dispatches websocket actions instead of treating them as
  unknown success no-ops.
- `$websocket.open` resolves and allowlists `ws`/`wss` URLs, opens through an
  injectable websocket seam, and continues the authored success chain
  immediately, matching legacy asynchronous service semantics.
- `$websocket.send` forwards `options.message` through the seam and continues
  success immediately.
- `$websocket.close` forwards close through the seam and continues success
  immediately.
- Websocket lifecycle callbacks trigger named legacy actions:
  `$websocket.onopen`, `$websocket.onmessage`, `$websocket.onclose`, and
  `$websocket.onerror`.
- Message callbacks expose legacy `$jason` payloads with `message` and `type`
  (`string` or `bytes`); error callbacks expose `$jason.error`.
- Event callbacks are queued and drained outside the queue lock so nested
  websocket events do not deadlock, and one failing event cannot poison later
  websocket events.
- Production `AndroidWebSocketClient` uses OkHttp, suppresses stale callbacks
  across reconnect/release with generation/socket checks, de-duplicates close
  notifications per socket, and only shuts down the OkHttp client it owns.
- `networkClient` remains the final `ActionDispatcher` constructor parameter,
  preserving existing trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline legacy implementation. It does not add a richer websocket UI
or cross-platform websocket support, and asynchronous event actions refresh UI
only through the existing action/render paths.

## Verification

Added JVM coverage for:

- `$websocket.open` forwarding the resolved URL and continuing success before
  asynchronous events.
- `$websocket.onopen` named-action dispatch.
- `$websocket.onmessage` and `$websocket.onerror` legacy `$jason` payloads.
- `$websocket.send` and `$websocket.close` forwarding plus immediate success
  chains.
- Invalid websocket schemes triggering `$websocket.onerror` while preserving
  fail-soft immediate success semantics.
- Nested websocket events being queued until the current event completes.
- Failing websocket events, including `$return.error`, not poisoning later event
  delivery.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout refreshed the
remaining Android/Web parity gaps and recommended Android `$websocket` as the
next auditable slice. Dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer passes
caught and helped address stale socket callbacks across reconnects, event
payload interleaving, shared OkHttp shutdown, non-atomic socket publication,
event-queue reentrancy/deadlock, and queue poisoning after failing event
handlers.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime. The targeted command:

```bash
cd JASONETTE-Android/JasonetteApp && \
  ./gradlew test --tests com.jasonette.ActionDispatcherTest --no-daemon
```

failed before Gradle started with:

```text
The operation couldn’t be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
```

GitHub Actions CI run `29044652822` passed for exact implementation head SHA
`81edb348ff83360eb9eb48eb617008020b66b2f2`; its Android job completed
successfully. iOS, web-renderer, template-engine, and validate jobs were skipped
by path filters for this Android-scoped implementation commit, so this CI
evidence validates the Android slice only and is not cross-platform validation.
