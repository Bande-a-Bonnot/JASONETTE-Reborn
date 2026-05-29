---
id: "019e7612-d0c7-7d9f-94d2-99f211073f55"
status: open
priority: p2
issue_id: "049"
tags: [ios, actions, network, qa, jasonpedia]
dependencies: []
---

# Investigate Jasonpedia `$network` Eliza demo parse warning

## Problem Statement

During delegated iOS Simulator QA on 2026-05-29, the Jasonpedia Action →
`$network` → Eliza demo failed to load and displayed the generic warning:
`The data couldn’t be read because it isn’t in the correct format.` Retrying
left the app in the same warning state.

## Evidence

- QA report: `docs/qa/2026-05-29-ios-delegated-codex-xhigh-qa.md`
- Screenshot: `docs/qa/artifacts/2026-05-29-delegated-agent/action-network-eliza-warning.png`
- Repro path:
  1. Launch Jasonpedia demo.
  2. Tap `Action`.
  3. Tap `$network`.
  4. Tap `eliza, make a $network.request to node.js express based chatbot server...`.
  5. Tap `Retry` if shown.

## Recommended Action

1. Inspect `Jasonpedia/action/network` Eliza fixture and the current remote URL it targets.
2. Determine whether the failure is external demo-server drift, non-JSON response shape, or an iOS parser/action-dispatch mismatch.
3. If external drift, update the fixture to a reliable endpoint or add a clearer user-facing error.
4. If renderer-side, add a focused `ActionDispatcher`/`DocumentLoader` regression test for the response shape.
5. Re-run direct-fixture iOS Simulator QA for the Eliza flow.

## Acceptance Criteria

- [ ] Root cause is documented in this todo or a linked QA/solution note
- [ ] Eliza/network demo either loads successfully or fails with an intentional, useful message
- [ ] Relevant iOS unit tests cover any renderer-side fix
- [ ] Simulator QA evidence is captured under `docs/qa/artifacts/`
