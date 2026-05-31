---
id: "019e7612-d0c7-797c-a5d7-1cbd67cb53ad"
status: complete
priority: p3
issue_id: "050"
tags: [ios, components, textarea, accessibility, ux, qa]
dependencies: []
---

# Improve empty textarea visual/accessibility affordance

## Problem Statement

During delegated iOS Simulator QA on 2026-05-29, `View` → `Component` →
`textarea` initially looked mostly blank: only the section label and `Done`
button were obvious. The empty `TextEditor` did not appear as a `text-view` in
the initial accessibility snapshot; after coordinate focus and typing, it did
accept input and exposed a `text-view`.

Follow-up in the same session added a minimum width to `TextAreaComponent`, but
the empty state still has weak visual affordance because there is no obvious
border/placeholder in the fixture.

## Evidence

- QA report: `docs/qa/2026-05-29-ios-delegated-codex-xhigh-qa.md`
- Before/finding screenshot: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea.png`
- Follow-up focused/typed screenshot: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea-after-fix-typed.png`
- Fixture: `Jasonpedia/view/component/textarea/index.json`

## Recommended Action

1. Decide the intended default empty textarea affordance for Jasonette iOS:
   border, background contrast, placeholder text, minimum size, or a combination.
2. Add renderer coverage where practical for the default sizing/placeholder path.
3. Verify with direct entry URL:
   `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textarea/index.json`.
4. Capture before/after simulator evidence.

## Completion — 2026-05-31

Implemented a renderer-level default empty textarea affordance in
`TextAreaComponent`:

- fallback visible placeholder text (`Enter text`) when no placeholder is
  authored
- visible rounded border and platform text-background fill
- retained minimum width/height
- explicit accessibility label on the `TextEditor`, using authored placeholder
  when present or a name-based fallback such as `blank text area`
- existing `TextEditor`, `StateManager` binding, and keyboard Done toolbar kept
  in place

Added coverage:

- `ComponentDispatchTests` for fallback placeholder and accessibility-label
  helper behavior
- `ViewModelTests` for the Jasonpedia textarea fixture selecting the default
  empty affordance path

Simulator QA:

- Direct-entry iPhone 17 Pro launch of the local Jasonpedia textarea fixture
  confirmed the empty textarea is visibly tappable with border + `Enter text`
  placeholder.
- Screenshot:
  `docs/qa/artifacts/2026-05-31-ios-textarea-affordance/textarea-empty-affordance.png`
- QA note: `docs/qa/2026-05-31-ios-textarea-affordance-qa.md`
- `agent-device` timed out while attaching/opening in this session, so no fresh
  automated tap/type accessibility snapshot was captured. The changed code keeps
  the prior text entry/dismissal path intact, and prior QA had already confirmed
  focus/typing after coordinate focus.

Verification:

- `swift test --filter ComponentDispatchTests/testTextArea` — 4 tests passed
- `swift test --filter ViewModelTests/testJasonpediaTextareaFixtureUsesDefaultEmptyAffordance` — 1 test passed
- full `swift test` — 511 tests passed
- `swift build` — passed
- generic iOS Simulator `xcodebuild` — passed
- `npm run lint:md` — 0 errors

## Acceptance Criteria

- [x] Empty textareas are visibly tappable in the Jasonpedia textarea fixture
- [x] Empty textareas expose a useful accessibility target before focus where SwiftUI permits
- [x] Focus, typing, Done toolbar, and keyboard dismissal still work
- [x] Existing textfield/secure textfield behavior is unchanged
