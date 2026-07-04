---
id: "019f2f61-6d01-7d2e-a55d-f4eb424e27ae"
status: complete
priority: p2
issue_id: "071"
tags: [web, parity, components, actions, state]
dependencies: []
---

# Web control state and action parity

## Problem Statement

Legacy native Jasonette components store named control values into runtime state
and can fire authored change actions. Android reference text fields update
`model.var[component.name]`, which is exposed to templates as `$get`, and switch
components execute authored actions on changes. Current web components rendered
textfield, textarea, slider, and switch controls, but DOM value changes did not
update renderer state, so later `$render` actions/templates could not see the
submitted value through `$get`.

## Acceptance Criteria

- Named web controls update renderer local state exposed as `$get`.
- Textfield/textarea/slider values are stored as strings, matching DOM form
  values and current `$get` template behavior.
- Switch values are stored as booleans.
- Authored control `action`/legacy `trigger` handlers run on value changes after
  `$get` is updated, not just on ordinary clicks.
- Existing button/action click behavior is preserved.

## Completed

Added renderer-level `input`/`change` listeners scoped to each
`JasonetteRenderer` root. Named form controls now update `state.local`; controls
with `data-action`/`data-trigger` execute their action after the state update.
Layout action wiring now avoids installing generic click handlers for form
controls so textfields/sliders/switches do not execute actions on focus/click
before their value changes.

## Verification

```bash
npm run test --workspace=@jasonette/web -- actions-parity.test.ts layouts.test.ts
npm run typecheck --workspace=@jasonette/web
npm run test --workspace=@jasonette/web
npm run build --workspace=@jasonette/web
```
