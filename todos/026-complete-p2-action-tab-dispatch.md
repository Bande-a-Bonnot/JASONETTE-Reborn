---
status: complete
priority: p2
issue_id: "026"
tags: [ios, tabs, actions, code-review]
dependencies: []
---

# Dispatch actions for action-only tab items

Completed: 2026-05-16

## Problem Statement

A footer tab can declare an `action` block instead of an `href`/`url`:

```json
{ "text": "Refresh", "action": { "type": "$reload" } }
```

The new tab coordinator (PR #20) currently **rejects** action-only
items at `TabDescriptor(from:)` construction — they never make it into
the shell. That's a safe default, but it means authors with a valid
`action` tab see the item silently disappear instead of firing when
tapped. CodeRabbit and Copilot both flagged it as a missing feature.

## Findings

- Rejection site:
  `JASONETTE-iOS/.../Navigation/JasonetteNavigationCoordinator.swift`
  (TabDescriptor.init?(from:)) — see the action-only guard
- `TabDescriptor.Target` already has a `.action(JasonAction)` case, so
  the data model is ready
- `JasonetteTabShell.handleTap` already has a `.action` branch that
  currently prints a debug message and returns
- Need: a way to dispatch a `JasonAction` from the shell. The usual
  path is through `ActionDispatcher` hanging off a `JasonetteViewModel`
  — but the shell deliberately does not own a VM. Options:
  1. Pass a dispatcher closure in via the environment
     (e.g. `jasonetteDispatch: (JasonAction) -> Void`), installed by
     the selected tab's VM
  2. Give the shell its own shell-scoped dispatcher that can handle
     shell-relevant actions (`$reload` on the current tab, `$href`,
     `$switch`) and forwards the rest to the currently-selected VM
- Option 2 is closer to the legacy Obj-C behaviour (`JasonTabBar` had
  direct access to the action runtime)

## Recommended Action

1. Decide between env-closure and shell-dispatcher (likely the latter).
2. Stop rejecting action-only descriptors in the coordinator; let them
   build with `.action(JasonAction)` targets.
3. Implement `handleTap` for `.action` in `JasonetteTabShell`:
   - `$reload` → forward to the currently-selected tab's VM
   - `$href` / `$switch` → route through the existing
     `jasonetteSwitchTab` env closure where applicable
   - Unknown types → log + no-op, matching how
     `ActionDispatcher` handles unknown actions inside a document
4. Tests: action-only tab dispatches, inline `$reload` hits the active
   tab's VM, unknown action is a silent no-op (no crash).

## Acceptance Criteria

- [x] Tab items with `action` (and no `href`/`url`) are constructed
      and rendered
- [x] Tapping an action tab invokes the declared action
- [x] The active tab's VM state is correctly in scope when the action
      reads `{{$jason}}` etc.
- [x] Unknown action types are non-fatal

## Completion Notes

- `TabDescriptor.Target.action(JasonAction)` is restored and action-only
  footer-tab items now construct descriptors instead of being rejected.
- `JasonetteTabShell` owns a shell-scoped `TabActionRegistry`; mounted
  `JasonetteView` instances register their active VM action handler via
  environment using the current tab ID.
- Tapping an action tab forwards the action to the currently-selected tab's
  active VM, so `$reload`, `$href`/`transition:"switch"`, `$set`, and unknown
  actions follow the same `ActionDispatcher` behavior as in-document actions.
- Tabs with only action/web/app targets still do not promote to shell mode,
  because there is no selectable document content to mount.
- Coverage added in `TabNavigationCoordinatorTests` for action-only descriptor
  construction, action tabs alongside selectable tabs, no-selectable fallback,
  selected-tab dispatch, missing-handler no-op, and selected VM state scope.
  Full iOS suite: 436 tests passing.

## Notes

Source: CodeRabbit + Copilot on PR #20 (2026-04-19).
Rejection in the coordinator is intentional interim behaviour — this
todo removes that gate once dispatch is plumbed end-to-end.
