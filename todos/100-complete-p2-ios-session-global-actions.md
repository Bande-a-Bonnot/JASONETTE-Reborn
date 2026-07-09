---
id: "019f482e-ce8c-7ad0-8126-772f9951a9ba"
status: completed
priority: p2
issue_id: "100"
tags: [ios, parity, actions, session, global, network]
dependencies: ["067"]
completed_at: "2026-07-09"
---

# Complete iOS `$session` / `$global` action baseline

## Outcome

iOS now recognizes `$session.set`, `$session.reset`, `$global.set`, and
`$global.reset` in the built `JASONETTE-iOS/JasonetteApp` renderer:

- `StateManager` keeps `$global` separate from local/cache state and persists it
  through a dedicated UserDefaults-backed `jasonette:global` store.
- `StateManager` keeps domain-scoped `$session` options in a dedicated
  UserDefaults-backed `jasonette:session` store and normalizes persisted nested
  dictionaries on reload.
- `$global.set` stores structured option values, returns the full updated global
  object under `$jason`, and exposes `$global` to success-chain templates.
- `$global.reset` removes only listed `options.items` keys and returns the full
  updated global object under `$jason`.
- Missing or malformed `$global` options abort without running success/error
  continuations, matching legacy fail-soft behavior.
- `$session.set` normalizes `domain` or `url` to a lowercase host, stores the
  authored session options, and exposes success payload `{}` under `$jason`.
- `$session.reset` removes the normalized domain session and exposes success
  payload `{}` under `$jason`.
- Missing `$session` domain/url aborts without success/error continuations.
- `$network.request` supports legacy `header` and `data` aliases while retaining
  existing `headers` and JSON `body` support.
- Authored `header` takes precedence over `headers`; authored blocked headers are
  stripped; session headers are applied last for legacy parity and provenance
  safety.
- Session body parameters decorate matching-domain requests: GET/HEAD/DELETE use
  query parameters, while POST/PUT/PATCH use `application/x-www-form-urlencoded`
  bodies unless an explicit JSON `body` is supplied. Authored `data` replaces the
  stored session body.
- `JasonetteViewModel` exposes `$global` in render template contexts.

This is a baseline legacy runtime implementation. It does not implement richer
legacy HTML cookie reset behavior beyond the action stores and network request
header/body decoration.

## Verification

Added Swift coverage for:

- `$global.set` structured payload storage, `$jason` return payloads, and
  `$global` template access from success chains.
- `$global.reset` removing only listed keys and returning the updated payload.
- Missing/malformed `$global` options aborting without success/error chains.
- `$session.set` normalizing domain/url, including bare hosts beginning with
  `http`, decorating matching-domain requests, and `$session.reset` removing the
  session.
- GET and DELETE session body decoration through query parameters.
- POST `data` form bodies replacing stored session body values.
- Authored blocked headers staying stripped even when same-key session headers
  exist; session headers remain provenance-safe and applied last.
- `StateManager` maintaining persistent separate global/session stores with
  suite-backed test isolation.
- `JasonetteViewModel` exposing `$global` to render templates.

Dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout and reviewer passes
compared current Swift with legacy iOS `JasonSessionAction`, `JasonGlobalAction`,
and `JasonNetworkAction`. Reviews caught and helped address brittle session
UserDefaults decoding, blocked-header/session provenance, legacy session-body
fallback semantics, `header` versus `headers` precedence, DELETE parameter
placement, bare `httpbin.org` domain normalization, and malformed raw global
options.

Local verification:

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter 'StateManagerTests|ActionDispatcherTests/testGlobal|ActionDispatcherTests/testSession|SecurityTests/testAuthoredBlockedHeadersCannotBypassViaSessionHeaderProvenance|SecurityTests/testStrips|SecurityTests/testAllowsCustomHeaders|ViewModelTests/testRenderContextExposesGlobalStore'`
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 612 tests, 0 failures.

GitHub Actions CI run `29039990110` passed for exact implementation head SHA
`e263bf997bf41dd0c4434d9860ae919a9a133c37`; its iOS job completed
successfully. Android, web-renderer, template-engine, and validate jobs were
skipped by path filters for this iOS-scoped implementation commit, so this CI
evidence validates the iOS slice only and is not cross-platform validation.
