# iOS todo 109: one keyboard Done control

Status: active, authorized 2026-10-05; planning gate in progress.

Contract: [todo 109](../../todos/109-fix-ios-duplicate-keyboard-done-controls.md).
Model assignment: GPT-6.1 Sol high planner/implementer; independent GPT-6.1 Sol
xhigh reviewer. Reuse bounded contexts where possible, with one host build lease
and two jobs. Root owns Git, gates, iOS QA, evidence, and todo closure.

The planner first reports its proposed ownership design and exact file scope;
root and the independent xhigh reviewer approve the concrete plan before edits.
The same high worker then implements the approved scope, including behavioral
regressions where a policy seam supports them. Workers do not run builds or tests.
Root executes the regression red gate before releasing implementation, then
serial green gates and native acceptance. Preserve unrelated AGENTS.md/CLAUDE.md
modifications and the two historical untracked arbiter JSON files.

## Planning gate

Inventory `KeyboardDismiss.swift`, plain/secure input, textarea, structural footer,
and document hosting. Confirm SwiftUI keyboard toolbar aggregation and choose
one owner per document or one active focused input. Write the concrete plan and
reconcile file ownership before dispatch. Preserve iOS16 and existing platform
guards. No new capability, SDK, entitlement, or external service is expected.

## Regression and implementation gates

Create a meaningful failing focus/ownership regression if the chosen design has
a testable policy seam. Do not mirror source text or add NSHostingView XCTest
rendering tests (previous host hangs). Native screenshots are the decisive count
and clipping check. Preserve Return/Done behavior, authored button actions,
multiline content, secure masking, and footer binding/sending.

Implement only the agreed input/toolbar ownership scope. Independent xhigh
review checks focus lifecycle, multiple documents/navigation, mixed contexts,
secure/textarea/structural footer callers, and iOS16 API compatibility. Repair
concrete findings before the final host build.

## Native acceptance

Use the retained iPhone17Pro/iOS26.2 simulator and pinned agent-device workflow.
Every device command is elevated. Test normal Home→View→Component→textfield,
textarea, and the mixed appearance fixture. Focus each input family, switch
between fields, dismiss, refocus, navigate/back, and toggle system light/dark.
Exactly one readable system Done control must be visible, with no edge clipping
or stale toolbar after dismissal. Capture before/after evidence, restore light
and Home, close the session/server, shut down the QA simulator.

Run focused tests and the full Swift suite with `--jobs 2`, then a fresh
provenance-correct iOS build with `-jobs 2`. Close only after review and native
acceptance pass. No worker launches builds, simulator commands, Git mutations,
or further agents independently.
