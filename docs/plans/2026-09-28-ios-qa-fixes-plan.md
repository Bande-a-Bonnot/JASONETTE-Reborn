# iOS QA fixes: styling and horizontal layout

Status: planning

## Approved scope

Implement the three-todo starting order approved on 2026-09-28:

1. [105 — component background bounds](../../todos/105-fix-ios-component-background-bounds.md)
2. [103 — fixed-width button labels](../../todos/103-fix-ios-fixed-width-button-label-truncation.md)
3. [104 — horizontal layout distribution](../../todos/104-fix-ios-horizontal-layout-width-distribution.md)

The linked todos and the [exploratory QA report](../qa/2026-09-26-ios-luna-exploratory-qa.md)
are the source of truth for observed behavior and definitions of done. Scope is
the Swift iOS renderer. Other open todos remain separate.

## Agent workflow

- A `gpt-6-sol` high planner reads this file and the linked todos, researches
  the current code and tests, and adds a concrete implementation and verification
  plan below before product edits begin.
- One `gpt-6-luna` xhigh implementer works through the three todos in the
  approved order, using focused TDD and atomic commits. It updates each todo's
  status and evidence only after its definition of done is satisfied.
- The same `gpt-6-sol` high agent performs a final review of the diff and test
  evidence. The implementer addresses confirmed defects, with another focused
  review only if needed.
- Reuse these agents and avoid parallel work on the same files to limit model
  usage and merge overhead.

## Guardrails

- Preserve the unrelated existing `AGENTS.md`, `CLAUDE.md`, and July arbiter
  working-tree changes.
- Follow the repository's SwiftUI style and `JasonStyle` Three-Place Rule.
- Verify focused tests as each slice lands, then run the full iOS Swift package
  test suite. Capture simulator visual evidence for the authored examples when
  the simulator is available. Treat visual verification as a real completion
  gate for these rendering bugs.
- Update `docs/HANDOFF.md` at the end. Do not push or deploy as part of this
  implementation pass.

## Sol implementation plan

To be completed by the planner before product edits.
