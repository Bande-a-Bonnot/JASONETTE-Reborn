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

## Simulator note

A device-specific iPhone 17 Pro simulator QA attempt was started, but
`xcrun simctl bootstatus 61EA0147-56E4-4399-8D51-F98A93B708A6 -b` did not
progress past `Waiting on BackBoard` before the 300-second command timeout. No
app-level screenshot was captured in this pass. The fixture behavior is covered
by focused iOS unit tests plus JSON/schema validation; re-run direct-entry
Simulator QA after CoreSimulator is healthy or after the fixture is deployed to
GitHub Pages.

Suggested direct-entry URL after deploy:

```bash
ENTRY_URL="https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/network/eliza.json"
xcrun simctl launch --terminate-running-process booted com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"
```
