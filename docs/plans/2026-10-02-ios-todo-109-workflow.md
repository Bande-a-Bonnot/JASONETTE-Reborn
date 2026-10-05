# iOS todo 109: one keyboard Done control

Status: complete 2026-10-05. Reviewed source `9122a7a` pushed; local/native gates,
exact-source GitHub CI and Xcode Cloud archive pass. [Verification record](../qa/2026-10-05-ios-keyboard-verification.md)
contains native acceptance and provenance. Owned QA session/server closed,
normal Home/light restored and retained simulator verified Shutdown.

Contract: [todo 109](../../todos/109-complete-p3-ios-duplicate-keyboard-done-controls.md).
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

### Concrete design reviewed 2026-10-05

Use one keyboard toolbar on `JasonetteView.documentBody`. Each document owns
a stable `@State` UUIDv7, passed to descendants through an optional environment
key. Plain/secure TextField, TextEditor and both structural footer field branches
publish that ID with `focusedValue`. A document toolbar modifier reads
`@FocusedValue` and contributes Done only when its ID matches current focus.
Use `focusedValue`, not `focusedSceneValue` or `.focusable()`. No ID fallback
outside a document; no focus registry, keyboard notifications, shared Bool,
or per-input IDs. Preserve UIKit dismissal and accent-color foreground.

Approved source scope: `Components/KeyboardDismiss.swift`,
`Components/TextFieldComponent.swift`, `Components/TextAreaComponent.swift`,
and `Rendering/JasonetteView.swift`, all under
`JASONETTE-iOS/JasonetteApp/Sources/Jasonette/`.
New focus plumbing is iOS-only; optional focused-value API is available on
iOS 16 in the installed SDK interface. Use explicit UI actor isolation where
required so the older CI SDK remains supported.

The existing public-field and mixed-fixture screenshots are the behavioral red:
three and six system Done controls respectively. Root inspected the public
baseline image before releasing implementation. A UUID equality predicate test
would not catch the duplicated toolbar placement; independent xhigh design
review recommends native count/lifecycle regression and existing meaningful
input tests instead of a synthetic policy seam. Capture a fresh baseline when
automation recovers, without holding implementation on the host startup.

Mandatory lifecycle case: focus a tab input, switch tabs without tapping a new
field, and verify no hidden document keeps a stale keyboard/toolbar. Tabs stay
mounted via opacity, so disappearance cannot establish focus ownership. Expand
shell scope only for a concrete demonstrated defect, with a reviewed follow-up.

### Native follow-up scope approved 2026-10-05

Source `27d9908` passes public plain/secure single-control and dismissal checks,
but actual Inputs → Other tab selection through the visible icon leaves the
keyboard and system Done active without focusing any Other input. The selected
navigation title is `Keyboard 109 Other`; the captured before/after state proves
the tab changed. Hidden stacks remain mounted. This fails the mandatory native
focus lifecycle gate. Artifact: `tab-switch-stale-keyboard.png` under the
canonical artifact directory.

Independent xhigh reviewer approved adding one iOS-guarded
`KeyboardDismiss.dismiss()` in the existing `onChange(of: shell.selectedTabID)`
callback of `Rendering/Navigation/JasonetteTabShell.swift`. This covers direct,
action/URL and restored selection paths, preserving mounted state. Approved
follow-up product scope is that file only; keep the four-file owner design.
No toolbar/tab-bar layout overhaul. Root owns the native red/green check and
fresh final build. Reviewer must check the scoped follow-up before that build.

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

Canonical host/device values for this run:

- Simulator: `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB` (retained iPhone 17 Pro, iOS 26.2).
- Pinned CLI: `/private/tmp/jasonette-device-20261002/node_modules/.bin/agent-device`.
- State directory: `/private/tmp/jasonette-device-state-20261002`.
- UUIDv7 session: `01a10bb0-17dc-7f2f-953d-495ee1a4dd6e`.
- Artifacts: `docs/qa/artifacts/2026-10-05-ios-keyboard/`.
- Local appearance fixture: `docs/qa/fixtures/ios-appearance-107/index.json`.
- Root-authored lifecycle fixtures: `docs/qa/fixtures/ios-keyboard-109/`.
- Fixture server: `127.0.0.1:8765`, owned PID 52338.
- Derived data: `/private/tmp/JasonetteIOSQAFixes` (reuse cache, update provenance).

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
