---
id: "019f2ece-a72e-7b97-8879-62b77b79d048"
status: open
priority: p1
issue_id: "066"
tags: [web, parity, actions, rendering, jasonpedia]
dependencies: []
---

# Web action/render parity baseline

## Problem Statement

The current web renderer can statically render many Jasonette documents, but the
parity audit found that interactive action activation and render data propagation
are incomplete compared with current iOS behavior and legacy Jasonette runtime
expectations.

Key gaps:

- Component `action` and named `trigger` are not wired from rendered items.
- `$render` ignores incoming success payloads and `options.template`.
- Render contexts omit or inconsistently expose `$get`, `$cache`, `$params`, and
  `$response`.
- `$href`, `$back`, and `$close` are not registered actions.

See `docs/research/2026-07-04-cross-platform-parity-audit.md`.

## Acceptance Criteria

- Clicking a component with `action` executes that action.
- Clicking a component with legacy `trigger` resolves and executes the named
  action from `head.actions`.
- `$set` followed by `$render` updates DOM from `$get`/local state.
- `$network.request` success exposes a `$response` payload to success chains and
  `$render` templates.
- `$render` supports `options.template` for named templates.
- `$href`, `$back`, and `$close` are registered with safe URL handling and
  existing renderer navigation semantics.
- Add focused Vitest coverage plus at least one Jasonpedia fixture regression
  test for the affected paths.

## Suggested Files

- `packages/web-renderer/src/renderer.ts`
- `packages/web-renderer/src/actions/index.ts`
- `packages/web-renderer/src/layouts/index.ts`
- `packages/web-renderer/src/components/index.ts`
- `packages/web-renderer/src/types.ts`
- `packages/web-renderer/test/`

## Verification

```bash
npm run test --workspace=@jasonette/web
npm run typecheck --workspace=@jasonette/web
npm run lint:md
```
