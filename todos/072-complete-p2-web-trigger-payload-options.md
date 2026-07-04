---
id: "019f2f75-bcd7-7dd5-8b8f-984c11351c61"
status: complete
priority: p2
issue_id: "072"
tags: [web, parity, actions, lambda, triggers]
dependencies: ["066"]
---

# Web trigger payload and action-option templating parity

## Problem Statement

The web action baseline could execute component actions and named `trigger`
actions, but it did not pass authored trigger payloads into the named action and
it did not template action `options` against the current action payload. Legacy
Jasonette action/lambda flows rely on this behavior: component actions such as
`{ "trigger": "banner", "options": { "id": "top" } }` expect the named
banner action to read `{{$jason.id}}`, and `$network.request` success triggers
expect named actions to read fields from the response payload.

This gap was backed by the parity audit's web action/render finding and by the
Jasonpedia `action/lambda` and `webcontainer/lots` fixtures. iOS already has
coverage for trigger payload propagation into named actions; Android currently
has named-trigger resolution coverage from the runtime baseline but not the
richer trigger-payload semantics.

## Acceptance Criteria

- Named `trigger` actions receive the triggering action's `options` as `$jason`.
- `$lambda` passes `options.options` as `$jason` to the named action it calls.
- Action `options` are templated against `$jason`, `$get`, `$cache`, `$params`,
  and `$response` before the action handler executes.
- Success/error continuation arrays execute in order, preserving legacy action
  chain behavior and retaining payloads across side-effect-only items.
- Existing web action, render, network, and control-action behavior remains
  intact.

## Completed

Updated the web action executor to normalize each action before dispatch by
rendering its `options` against the current action payload context. Trigger-only
actions now dispatch the referenced head action with the trigger's authored
`options` as payload. `$lambda` now dispatches named actions with
`options.options` as payload. The executor also handles legacy continuation
arrays for both `success` and `error` branches.

Added Vitest coverage for trigger payloads, `$lambda` payloads, network success
payloads in named triggers, whole-expression string options such as
`"{{$jason}}"`, ordered success arrays, mixed/conditional action arrays,
payload preservation across side-effect/state-mutating actions, nested action
arrays, and error arrays templated against the thrown error payload.

## Verification

```bash
npm run test --workspace=@jasonette/web -- actions-parity.test.ts
npm run typecheck --workspace=@jasonette/web
npm run test --workspace=@jasonette/web
npm run build --workspace=@jasonette/web
```
