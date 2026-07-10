---
id: "019f4b7b-176a-7a67-8c09-51ae288ea0c3"
status: completed
priority: p2
issue_id: "102"
tags: [web, parity, actions, session, global, network]
dependencies: ["066", "072", "073", "074"]
completed_at: "2026-07-10"
---

# Complete Web `$session` / `$global` action baseline

## Outcome

Web now recognizes `$session.set`, `$session.reset`, `$global.set`, and
`$global.reset` in `packages/web-renderer`:

- `AppState` includes separate `$global` and domain-scoped `$session` stores.
- `JasonetteRenderer` loads `$global` and `$session` from localStorage-backed
  `jasonette:global` and `jasonette:session` stores.
- `$global.set` stores structured option values, persists the full global store,
  returns it under `$jason`, and exposes `$global` to action success templates.
- `$global.reset` removes only listed `options.items` keys, persists the updated
  store, and aborts malformed options without running success/error chains.
- `$session.set` normalizes authored `domain` or `url` to a lowercase host,
  stores the authored session options, and persists the session map.
- `$session.reset` removes the normalized domain session.
- Missing or malformed session/global options abort without success/error
  continuations to match the legacy fail-soft behavior used in current iOS and
  Android baselines.
- `$global` is exposed in action and render template contexts through
  `RenderContext`.
- `$network.request` now supports legacy `header` and `data` aliases while
  retaining existing `headers` and JSON `body` behavior.
- Matching-domain session headers decorate requests after authored headers, and
  session body parameters decorate GET/HEAD/DELETE URLs or non-GET form bodies
  unless authored `data` or explicit `body` is supplied.
- `$network.request` response payloads continue to drive success chains and
  sequential action arrays.
- `@jasonette/template-engine` export-map ordering now puts `types` before
  runtime conditions so downstream TypeScript consumers can resolve declarations.

This is a baseline legacy runtime implementation. It does not implement richer
cookie/html-session bridging or additional webcontainer bridge behavior beyond
session/global stores and network request header/body decoration.

## Verification

Added Vitest coverage for:

- `$global.set` persistence, `$global` action-template access, render-template
  access, and `$jason` payloads.
- `$global.reset` removing only listed keys and malformed global actions
  aborting without success/error chains.
- `$session.set` matching-domain request decoration with session headers and
  session body data.
- Authored `data` replacing session body data for form requests.
- `$session.reset` clearing later request decoration.
- Explicit falsy `body` values suppressing session body fallback.
- Handcrafted action state without initialized session storage not crashing.
- `$network.request` response payload propagation across sequential action
  arrays.

Dedicated read-only `openai-codex/gpt-5.5` / `xhigh` reviewer checked the
uncommitted slice against legacy Web/iOS semantics. The review found no critical
issues and helped address explicit-body/session fallback and handcrafted-state
edge cases before commit.

Local verification:

- `npm run test --workspace=@jasonette/web -- actions-parity.test.ts` — 32
  tests passed.
- `npm run typecheck --workspace=@jasonette/web`.
- `npm run typecheck --workspace=@jasonette/template-engine`.
- `npm run build --workspace=@jasonette/template-engine`.
- `npm run test --workspace=@jasonette/template-engine` — 141 tests passed.
- Focused web suite before commit: `npm run test --workspace=@jasonette/web --
  actions-parity.test.ts renderer.test.ts integration.test.ts components.test.ts`
  — 69 tests passed.
- `npm run build --workspace=@jasonette/web`.
- Post-commit full `npm run test --workspace=@jasonette/web` first failed on
  host `ENOSPC`; after disk cleanup it reached 101/102 tests passed but one CLI
  test exceeded Vitest's 5s per-test timeout in the parallel full-suite run.
  Isolated reruns of `cli.test.ts` and `cli.test.ts -t 'validates a correct'`
  passed.

GitHub Actions CI run `29080105310` passed for exact implementation head SHA
`3c2718ff2ab7351c1edeff0d5694a8b58d130e07`; its `web-renderer` and
`template-engine` jobs completed successfully. Android, iOS, and validate jobs
were skipped by path filters for this web/template-scoped implementation commit,
so this CI evidence validates the web/template slice only.
