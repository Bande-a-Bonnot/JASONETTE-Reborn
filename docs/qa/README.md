# QA Notes

This directory stores exploratory QA passes and supporting evidence.

## iOS Simulator Build / Install

From the active Tuist app root, generate the ignored local Xcode project before
using `xcodebuild` so `Project.swift` changes are reflected in the build graph:

```bash
cd JASONETTE-iOS/JasonetteApp
mise exec -- tuist generate --no-open
```

Preferred device-specific simulator build for the booted iPhone 17 Pro QA
simulator:

```bash
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Install and launch:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette
```

A generic simulator build is also valid when no specific booted device is
needed:

```bash
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  build
```

As of 2026-05-28, the old asset-catalog workaround that cleared
`ASSETCATALOG_COMPILER_APPICON_NAME` and
`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` is no longer required. The
missing `AccentColor` asset has been added, and the device-specific build has
been re-verified on iPhone 17 Pro / iOS 26.2.

## iOS Simulator QA with `agent-device`

Use `agent-device` for agent-driven simulator QA. Raw `simctl` is excellent for
boot/install/launch/screenshot, but it does not provide high-level touch or
accessibility interaction. Posting CoreGraphics events to the Simulator window is
fragile and may fail under agent harness permissions. `agent-device` works by
bootstrapping an XCTest runner and exposing compact accessibility snapshots plus
interaction commands.

### Install / invoke

Prefer `npx` so the current CLI is used without adding a repo dependency:

```bash
npx --yes agent-device@latest --version
npx --yes agent-device@latest help workflow
```

The CLI help is authoritative; read `help workflow` before a QA pass.

### Basic loop

```bash
# Discover devices/apps
npx --yes agent-device@latest devices --platform ios
npx --yes agent-device@latest apps --platform ios

# Open the app and create a named session
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonetteqa \
  --platform ios \
  --device "iPhone 17 Pro" \
  --relaunch

# Inspect visible UI and get refs
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios

# Interact using refs, then re-snapshot
npx --yes agent-device@latest press @e16 --session jasonetteqa --platform ios
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios

# Capture visual evidence when useful
npx --yes agent-device@latest screenshot docs/qa/artifacts/YYYY-MM-DD-ios-simulator/example.png \
  --session jasonetteqa \
  --platform ios

# End the session
npx --yes agent-device@latest close --session jasonetteqa --platform ios
```

### Debug entry URL override

Debug iOS builds accept an HTTP(S) root document override without editing
`Sources/JasonetteApp-iOS/App.swift`. Release/TestFlight builds ignore the
override and keep the production Jasonpedia demo URL.

Launch-argument form:

```bash
ENTRY_URL="https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/html/index.json"
xcrun simctl launch --terminate-running-process booted com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"
```

Environment-variable form (`simctl` injects child-process environment via the
`SIMCTL_CHILD_` prefix):

```bash
ENTRY_URL="https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/html/index.json"
SIMCTL_CHILD_JASONETTE_ENTRY_URL="$ENTRY_URL" \
  xcrun simctl launch --terminate-running-process booted com.bande-a-bonnot.jasonette
```

To drive the launched app with `agent-device`, attach without `--relaunch` so
the already-running process keeps its override:

```bash
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonetteqa \
  --platform ios \
  --device "iPhone 17 Pro"
```

### Local tab/action-tab fixture strategy

A small local fixture lives in `docs/qa/fixtures/ios-simulator-tabs/`. Serve it
over localhost so it still uses the renderer's normal HTTP document-loading
path:

```bash
python3 -m http.server 8765 --directory docs/qa/fixtures/ios-simulator-tabs
```

In another shell, launch the Debug app directly into the fixture:

```bash
ENTRY_URL="http://127.0.0.1:8765/index.json"
xcrun simctl launch --terminate-running-process booted com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"
```

QA flow:

1. Confirm the app opens on “Home tab fixture”.
2. Tap the “Detail” document tab and confirm “Detail tab fixture”.
3. Return to “Home”, tap “Go Detail”, and confirm it switches to the existing
   Detail tab instead of pushing a duplicate view.
4. Tap “Alert” and confirm the selected tab handles the `$util.alert` action.

The same directory also includes `chrome-index.json` plus related `chrome-*`
files for tab navigation-chrome QA. Use
`http://127.0.0.1:8765/chrome-index.json` as the entry URL to exercise three
mounted document tabs, per-tab toolbar buttons, and pushed child pages.

### Operational notes from 2026-05-18/19

- The first `snapshot` can take a long time or time out while the XCTest runner
  starts. Retry once before assuming the app is inaccessible.
- 2026-06-12 / `agent-device` 0.17.2: when the iOS runner is cold, the default
  prepare/open path can exceed the tool's daemon request budget. On this machine,
  `prepare ios-runner --timeout 240000` timed out, while
  `prepare ios-runner --timeout 360000` succeeded in about 166s. `open --help`
  does not expose a matching `--timeout` flag in 0.17.2, so `open` can still hit
  a fixed 90s daemon timeout before establishing an active app session. See
  `todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md` and
  `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/agent-device-065-diagnostics.md`.
- Screenshots may show an iOS breadcrumb back to `AgentDeviceRunner...`; this is
  a QA harness artifact.
- Prefer accessibility refs from `snapshot -i`. If a control is collapsed or
  unlabeled, use `snapshot -i -c --json` to inspect rects and coordinate-fallback
  only with an explanation.
- Re-snapshot after every navigation, modal, alert, tab tap, or reload.
- Keep a live QA markdown note and capture screenshots only when they support a
  finding or important confirmation.

## QA report expectations

Each pass should record:

- date/time
- commit SHA
- macOS/Xcode versions
- simulator device/runtime
- build/install/launch commands
- entry URL/config
- areas tested and not tested
- severity-sorted findings with reproduction steps and evidence
- non-issues / confirmed working behavior
- recommended follow-up tickets

See `2026-05-18-ios-simulator-complete-qa.md` for the first agent-device-backed
pass.
