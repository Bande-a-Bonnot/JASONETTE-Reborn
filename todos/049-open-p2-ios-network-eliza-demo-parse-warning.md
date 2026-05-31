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

## Progress — 2026-05-30

Root cause: fixture/server drift. The `eliza` list row navigated directly to
`https://jsonplaceholder.typicode.com`, which currently serves an HTML landing
page (`content-type: text/html; charset=UTF-8`) instead of a Jasonette JSON
document. iOS then correctly failed to decode that navigation target as a
`JasonDocument`, producing the generic format warning.

Fix implemented in working tree:

- Added `Jasonpedia/action/network/eliza.json`, a valid Jasonette document with
  a `$load` `$network.request` to
  `https://jsonplaceholder.typicode.com/comments?postId=1`.
- Updated `Jasonpedia/action/network/index.json` so the `eliza` row navigates to
  the local `eliza.json` fixture instead of the HTML endpoint.
- Added a `$network.request` error branch that renders a demo-specific
  `network_error` fallback message.
- Added iOS fixture coverage in `ViewModelTests` for the index route, maintained
  endpoint, rendered `$response` items, and fallback error message.
- Captured endpoint evidence in
  `docs/qa/artifacts/2026-05-30-ios-network-eliza-fixture/endpoint-checks.txt`.
- QA note: `docs/qa/2026-05-30-ios-network-eliza-fixture-qa.md`.

Verification:

- `jq empty Jasonpedia/action/network/index.json Jasonpedia/action/network/eliza.json`
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ViewModelTests/testJasonpediaNetwork` — 4 tests passed
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 507 tests passed
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed
- `npm run spec:validate` — 80 passed, 5 excluded
- `npm run lint:md` — 0 errors

Simulator direct-entry QA remains open: an iPhone 17 Pro boot attempt timed out
at `xcrun simctl bootstatus ... -b` after 300 seconds while waiting on
BackBoard, so no app screenshot was captured in this pass.

## Acceptance Criteria

- [x] Root cause is documented in this todo or a linked QA/solution note
- [x] Eliza/network demo either loads successfully or fails with an intentional, useful message
- [x] Relevant iOS unit tests cover any renderer-side fix
- [ ] Simulator QA evidence is captured under `docs/qa/artifacts/`
