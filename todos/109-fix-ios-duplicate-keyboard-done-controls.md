---
id: "01a0fe8a-a167-7c36-8581-940580e6350f"
status: open
priority: p3
issue_id: "109"
tags: [ios, keyboard, inputs, ux, qa]
dependencies: []
---

# Show one keyboard Done control on screens with multiple inputs

## Observed problem

Each input contributes its own keyboard toolbar item. The public textfield
screen displays three Done controls; the mixed appearance fixture displays
six, with the edge controls partly clipped. Dismissal works and 107 corrected
their contrast, but the repeated system controls add clutter and overflow.
This behavior predates the appearance fix; the pre-fix screenshot also shows it.

## Evidence

- [Pre-fix mixed toolbar](../docs/qa/artifacts/2026-10-02-ios-backlog/appearance-dark-multiline.png)
- [Final mixed toolbar](../docs/qa/artifacts/2026-10-02-ios-backlog/appearance-final-dark-toolbar.png)
- [Three public textfield controls](../docs/qa/artifacts/2026-10-02-ios-backlog/textfield-final-dark-focused.png)
- Shared `keyboardDoneToolbar()` adds a `ToolbarItemGroup` per input.
  Textfield, textarea, and structural footer callers install it independently.

## Definition of Done

- Exactly one system keyboard Done control appears while any input is focused,
  including mixed plain, secure, textarea, and footer fields.
- It dismisses the currently focused keyboard, preserving field values,
  multiline entry, secure masking, and authored submission actions.
- Its label remains readable in light/dark and mixed authored surfaces.
- No toolbar item remains when no input is focused; switching inputs does not
  duplicate controls or keep stale focus ownership.
- Focused regressions and native multi-input screenshots verify the result.

## Workflow

[Scoped workflow](../docs/plans/2026-10-02-ios-todo-109-workflow.md): GPT-6.1 Sol
high planning/implementation and an independent xhigh reviewer. Root owns
serial tests/build/device acceptance. Recorded as a new follow-up after 106–108;
implementation has not started.
