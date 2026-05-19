---
title: "Agent-driven iOS Simulator exploratory QA with agent-device"
date: 2026-05-19
category: best-practices
module: QA Workflow
problem_type: best_practice
component: ios-simulator-qa
applies_when: "An agent must perform exploratory QA of the iOS app in Simulator"
severity: medium
tags: [qa, ios, simulator, agent-device, xctest, exploratory-testing, documentation]
---

# Agent-driven iOS Simulator Exploratory QA with agent-device

## Context

This session needed a free-form end-to-end QA pass of the Jasonette Reborn iOS
app in Simulator. The first attempt used raw simulator tooling plus CoreGraphics
mouse events. That was enough to build/install/launch and capture screenshots,
but not enough to reliably interact with the app from the agent harness.

The successful pass used [`agent-device`](https://github.com/callstackincubator/agent-device),
which starts an XCTest runner and exposes accessibility snapshots, refs, presses,
text input, screenshots, and session state through a CLI.

No external LLM/provider/subagent was delegated during this run. The "subagent"
in practice was the local `agent-device` XCTest runner process; all triage and
documentation were done in this coding-agent session from command output,
screenshots, repository docs, and the conversation transcript.

## Process Learnings

### Use a QA charter, not a script

For exploratory QA, start with a charter that names the risk areas, then follow
what the app reveals. The useful findings in this pass came from curiosity:

- Template landing page looked too sparse → inspected fixture → found object-form
  `items` template directives rendering blank lists.
- Textfield demo had a secure field → filled it → confirmed secret text is
  exposed in plain text.
- Footer tab fixture had icon-only tabs → inspected accessibility → found
  unlabeled buttons and unclear selected state.

The live QA note should be written as the pass happens so failures, tool gaps,
and evidence paths are not reconstructed from memory.

### Prefer accessibility snapshots over screenshots for driving

Screenshots are evidence; accessibility snapshots are the control surface.

Useful loop:

```bash
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonetteqa --platform ios --device "iPhone 17 Pro" --relaunch
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios
npx --yes agent-device@latest press @e16 --session jasonetteqa --platform ios
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios
```

Use screenshots after a finding or important confirmation:

```bash
npx --yes agent-device@latest screenshot docs/qa/artifacts/YYYY-MM-DD-ios-simulator/finding.png \
  --session jasonetteqa --platform ios
```

### Raw Simulator input is the wrong abstraction for agents

`simctl` can boot, install, launch, and screenshot. It does not expose high-level
touch automation. Posting CoreGraphics events to the Simulator window can fail
because of accessibility/input-monitoring permissions, window coordinate scaling,
or harness isolation. Do not spend much time there if an XCTest/accessibility
runner is available.

### First runner startup may be slow

The first `agent-device snapshot` timed out while the runner bootstrapped. A
subsequent debug run showed the XCTest runner eventually printing listener-ready
markers and then serving snapshots. Retry once before declaring the tool broken.
Record diagnostic logs if the first run times out.

### Document tool artifacts honestly

`agent-device` screenshots can show an iOS breadcrumb back to
`AgentDeviceRunner...`. That is not an app bug. Record it as a QA harness
artifact so future readers do not mistake it for app UI.

## Technical Learnings

### Original Jasonette template syntax remains a compatibility risk

Jasonpedia still uses object-form directives under array-valued fields:

```json
"items": {
  "{{#each json_items}}": {
    "type": "vertical",
    "href": { "url": "{{url}}" },
    "components": [ ... ]
  }
}
```

The current Swift renderer/template pipeline rendered section headers but blank
item regions for this shape. This is a high-impact compatibility gap because it
hides large portions of Jasonpedia.

Tracked as `todos/039-ready-p1-object-form-items-template-directives.md`.

### Action-tab design needs shell intent before VM dispatch

Earlier in the session, action-only footer tabs were restored by forwarding the
action to the currently-selected tab's active VM through `TabActionRegistry`.
That was correct for `$reload`, `$set`, and unknown actions, but a plain `$href`
action that targets a declared tab must be interpreted as shell tab intent first.
Otherwise normal VM `$href` defaults to `.push` and puts tab destinations on the
selected tab's navigation stack.

The follow-up fix added a shell interception path:

1. If action is `$href` and resolves to a declared document tab, switch tab.
2. Otherwise dispatch to selected VM normally.

Design rule: **footer tab taps are shell intent until proven otherwise; document
button taps are document navigation intent.**

### Action dispatch scope belongs to the selected mounted tab

The selected tab's `JasonetteViewModel` owns state, document URL, action
handlers, and navigation context. A shell-level action dispatcher would need to
recreate or borrow all of that. The environment-registration pattern keeps the
shell decoupled while preserving VM scope:

- `JasonetteTabShell` owns `TabActionRegistry`.
- Each mounted `JasonetteView` registers a handler for its tab ID.
- Action tab taps dispatch to `selectedTabID`'s handler.

This preserves `{{$jason}}`/state/action semantics better than a global shell VM.

### Simulator QA exposed stale handoff wording

The handoff still described map as a stub, but the Map demo rendered MapKit
content in Simulator. Pins/region behavior may still be incomplete, but the
blank-stub characterization is stale and should be tightened when map work is
next touched.

## Implementation Learnings

### Tests were necessary but not sufficient

The Swift suite had 439 passing tests, including action-tab switch-vs-push
coverage. Simulator QA still found high-impact gaps in template compatibility,
secure entry, and demo rendering. Keep both:

- Unit tests for renderer/action semantics.
- Simulator exploratory QA for actual Jasonpedia compatibility and visual/a11y
  behavior.

### Add direct launch URL overrides for QA

Hardcoding the entry URL blocks direct QA of focused fixtures and ad-hoc local
JSON documents. A debug-only `JASONETTE_ENTRY_URL` or launch argument would let
agents open a targeted fixture without source edits/rebuilds.

Tracked as `todos/043-ready-p3-debug-launch-url-override-for-simulator-qa.md`.

### Accessibility is both test surface and product surface

The footer tab fixture was visually icon-only and exposed unlabeled buttons. For
agent QA, unlabeled controls make automation harder; for users, they are an
a11y bug. Add labels/selected state to tab cells, not just visual styling.

Tracked as `todos/042-ready-p3-footer-tab-accessibility-selected-state.md`.

## Design Learnings

### Structural elements need product semantics, not only rendering parity

Footer tabs are not just arbitrary buttons; they communicate selection, scope,
and navigation model. Restoring icon/style parity was necessary, but QA showed
that selected state and accessibility need explicit design treatment.

### Compatibility with original Jasonette is a product promise

Jasonpedia is both demo content and a compatibility suite. If an original
Jasonette authoring idiom renders blank, users will perceive the renderer as
broken even if the new schema path is technically cleaner. Treat high-value
Jasonpedia blank screens as product bugs, not fixture oddities.

### Secure input is a privacy contract

A field called secure/password that exposes raw text violates user expectation
and accessibility privacy. This should be handled as a correctness/privacy issue,
not merely a missing component feature.

## Key Findings from This Session

| Finding | Severity | Tracking |
|---------|----------|----------|
| Object-form `items` template directives render blank lists | P1 | `todos/039` |
| Secure textfield exposes plain text | P2 | `todos/040` |
| HTML component renders `[Unknown: html]` | P2 | `todos/041` |
| Icon-only footer tabs unlabeled / unclear selected state | P3 | `todos/042` |
| Debug launch URL override needed for focused QA | P3 | `todos/043` |
| Device-specific simulator build hang needs investigation | P3 | `todos/044` |

## Recommended QA Workflow Going Forward

1. Read `docs/qa/README.md`.
2. Build/install the app or use an existing installed simulator build.
3. Start an `agent-device` session with a named session ID.
4. Keep live notes in `docs/qa/YYYY-MM-DD-ios-simulator-*.md`.
5. Use `snapshot -i` for navigation and controls.
6. Capture screenshots for findings and representative confirmations.
7. Convert every actionable finding into a todo with evidence links.
8. Update `docs/HANDOFF.md` with the QA result and new highest-priority todos.

## Related Artifacts

- QA report: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- QA process README: `docs/qa/README.md`
- Action-tab commits:
  - `f6105fb Dispatch action-only footer tabs`
  - `51f0d11 Switch action href tabs instead of pushing`
- Simulator QA commit:
  - `40b041a Complete agent-device iOS simulator QA pass`
