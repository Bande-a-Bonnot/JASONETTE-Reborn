# iOS UI QA Queue Run — 2026-06-11

## Summary

Delegated a UI-focused iOS Simulator QA pass to a child QA agent using the
existing Debug app, direct-entry Jasonpedia URLs, screenshots, and the documented
`agent-device` workflow where possible.

## Environment

- Commit: `e3741bb`
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Primary simulator: iPhone 17 Pro / iOS 26.2
  (`61EA0147-56E4-4399-8D51-F98A93B708A6`)
- Note: another simulator was also booted during local follow-up, so future
  `simctl`/`agent-device` commands should pin the UDID/device name explicitly.

## Commands / Workflow

The QA agent reported running the documented build/install/launch flow:

```bash
cd JASONETTE-iOS/JasonetteApp
mise exec -- tuist generate --no-open
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  build
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette
```

Direct-entry launches used `-JasonetteEntryURL` for targeted Jasonpedia and local
QA fixtures.

`agent-device` attach/snapshot was attempted, but snapshots repeatedly timed out
in this session. Visual evidence was captured with Simulator screenshots instead.

## Areas Covered

- Production Jasonpedia demo launch.
- Jasonpedia Action index and selected action fixtures:
  - script/index
  - script/inline
  - addressbook
  - geo
  - vision
  - audio/vaultboy
- Jasonpedia Template fixtures:
  - template/index
  - template/csv
  - template/rss
- Component fixtures:
  - html
  - map
  - textfield
  - textarea
- Core fixtures:
  - core/index
  - core/snapshot
  - core/href/index
  - core/href/tabs
- Local tab/navigation QA fixtures under
  `docs/qa/fixtures/ios-simulator-tabs/`.

## Confirmed Working / No Obvious Regression

- Debug app built, installed, and launched on iPhone 17 Pro / iOS 26.2.
- Direct-entry URL override worked for Jasonpedia and local QA fixture pages.
- Production demo, Action index, Template index, CSV, RSS, HTML, map, textfield,
  textarea, core, and tab fixture pages rendered enough content for visual smoke.
- Local tab/navigation chrome fixtures loaded and produced screenshot evidence.

## Findings

### P3 — Map first-paint/loading state needs follow-up

The map fixture rendered native map content in the early screenshot, but changed
materially between short-wait and long-wait captures. This may be normal MapKit
tile settling, not a renderer bug, but warrants a focused follow-up to decide
whether an explicit loading/placeholder affordance is needed.

Evidence:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/09-component-map-shortwait.png`
- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/09-component-map-longwait.png`

Follow-up completed in `todos/063-complete-p3-ios-map-first-paint-loading-state.md`: a pinned-UDID direct-entry recheck captured 3s/6s/10s/15s screenshots with native map content visible by 3s and 0.0000% changed pixels between subsequent captures. No renderer change is needed.

### P3 — Vault Boy audio fixture uses HTTP GIF URLs blocked by ATS

The Vault Boy audio fixture rendered as a mostly blank page. The QA agent
reported an ATS failure for the fixture GIF URL:
`NSURLErrorDomain Code=-1022` for
`http://i.giphy.com/l41YybJPL0z2n1snm.gif`.

Evidence:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/20-action-audio.png`
- Source fixture references in `Jasonpedia/action/audio/vaultboy/index.json`.

Fixed in `todos/064-complete-p3-ios-vaultboy-audio-fixture-http-media-url.md`: the fixture now uses HTTPS GIF URLs and direct-entry Simulator smoke shows the Vault Boy media rendering.

### P3 — `agent-device snapshot` timed out repeatedly

The pass could not perform interactive tap/scroll/text-entry automation because
`agent-device snapshot` timed out. Screenshots were still captured, but this
limits future exploratory QA coverage of action chains, share sheets, text entry,
and pull-to-refresh/snapshot behavior.

Todo opened: `todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md`.

## Artifacts

Screenshots and the child-agent prompt envelope are stored under:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/`

## Follow-up Queue

- `todos/063-complete-p3-ios-map-first-paint-loading-state.md`
- `todos/064-complete-p3-ios-vaultboy-audio-fixture-http-media-url.md`
- `todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md`
