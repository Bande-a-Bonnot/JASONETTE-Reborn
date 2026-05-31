# iOS Network Eliza Fixture QA — 2026-05-30

## Environment

- Date: 2026-05-30
- Commit under test: `93bbcadc15ce840a50fcda1f4f4d506674f3bec0` plus working-tree fixture/test changes
- Target fixture: `Jasonpedia/action/network/eliza.json`
- Artifact directory: `docs/qa/artifacts/2026-05-30-ios-network-eliza-fixture/`

## Root cause

The Jasonpedia Action → `$network` → `eliza` row previously navigated directly to
`https://jsonplaceholder.typicode.com`. That endpoint currently returns an HTML
landing page (`content-type: text/html; charset=UTF-8`), not a Jasonette JSON
document. iOS correctly attempted to decode the navigation target as a
`JasonDocument` and surfaced the generic JSON decoding warning:
`The data couldn’t be read because it isn’t in the correct format.`

This is fixture/server drift rather than an iOS `$network.request` response-shape
bug.

## Fix verified

- The `eliza` row now points to a local Jasonette document, `eliza.json`, so the
  navigation target is valid Jasonette JSON.
- The new document demonstrates `$network.request` against the maintained JSON
  endpoint `https://jsonplaceholder.typicode.com/comments?postId=1`.
- The `$load` action has an explicit `error` branch that sets a demo-specific
  `network_error`, so endpoint failures render a helpful in-page message instead
  of a document parse warning.
- Endpoint evidence is captured in
  `docs/qa/artifacts/2026-05-30-ios-network-eliza-fixture/endpoint-checks.txt`.

## Commands

```bash
jq empty Jasonpedia/action/network/index.json Jasonpedia/action/network/eliza.json
cd JASONETTE-iOS/JasonetteApp && swift test --filter ViewModelTests/testJasonpediaNetwork
cd JASONETTE-iOS/JasonetteApp && swift test
cd JASONETTE-iOS/JasonetteApp && swift build
npm run spec:validate
npm run lint:md
```

## Simulator QA

A first device-specific iPhone 17 Pro simulator QA attempt timed out on
2026-05-30 while `xcrun simctl bootstatus ... -b` waited on BackBoard. A retry
on 2026-05-31 succeeded after checking memory pressure: `memory_pressure`
reported 34% system-wide memory free, and the iPhone 17 Pro simulator was
already booted.

Direct-entry Simulator QA used the local Jasonpedia fixture over HTTP:

```bash
python3 -m http.server 8766 --directory Jasonpedia
ENTRY_URL="http://127.0.0.1:8766/action/network/eliza.json"
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"
xcrun simctl io \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  screenshot docs/qa/artifacts/2026-05-30-ios-network-eliza-fixture/eliza-direct-entry.png
```

Result: the app rendered `$network Eliza demo`, explanatory copy, and fetched
JSONPlaceholder comment rows. It did not show the prior generic parse warning.
Screenshot evidence:
`docs/qa/artifacts/2026-05-30-ios-network-eliza-fixture/eliza-direct-entry.png`.

Note: `agent-device` attached to the app, but accessibility snapshots timed out
twice while starting/using the XCTest runner. Visual confirmation was captured
with `simctl io screenshot` instead.
