# iOS Simulator Complete QA Pass — 2026-05-18

## Environment

- Date/time: 2026-05-18 21:20–21:48 UTC
- Git commit SHA: `51f0d11b245306e4e04740ef2783648969546a66`
- Working tree at start: clean
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Entry URL: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`
- Build/run commands used:
  - Initial device-specific build attempted:
    `xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' -derivedDataPath DerivedDataQA CODE_SIGNING_ALLOWED=NO build`
  - Generic simulator build used after the first build hung:
    `xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedDataQA2 CODE_SIGNING_ALLOWED=NO ASSETCATALOG_COMPILER_APPICON_NAME= ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= build`
  - Install: `xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 DerivedDataQA2/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`
  - Launch: `xcrun simctl launch 61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette`
  - Unit/regression suite: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Build result: generic simulator build succeeded; first device-specific build hung during asset catalog processing.
- Test result: 439 tests, 0 failures.
- Local changes: this QA document and screenshot artifacts only.

## Summary

- Overall status: QA pass started, app built/installed/launched successfully, initial remote document rendered. Interactive simulator exploration is blocked in this harness because available command-line tools can capture screenshots but could not inject taps into the Simulator window.
- Most serious finding: QA process blocker — I could not drive touch input in the simulator from the current agent environment, so footer-tab/action-tab/navigation flows have not yet received a true manual E2E pass.
- Areas tested:
  - Build/install/launch on iOS simulator
  - Initial bootstrap fetch and render of `demo.json`
  - Screenshot capture
  - Existing Swift test suite
- Areas not tested / blocked:
  - Manual tapping through Jasonpedia links
  - Footer tab shell behavior
  - Action-only tab behavior
  - Back stack behavior after tab taps
  - Modal/web/app navigation
  - Pull-to-refresh / stress tapping / background-foreground

## Timeline / Running Notes

### 21:20 UTC — Environment capture

Recorded commit, macOS, Xcode, and simulator inventory. Working tree was clean at commit `51f0d11`.

### 21:22 UTC — First build attempt

Attempted to build `Jasonette-iOS` directly for the booted iPhone 17 Pro simulator with `CODE_SIGNING_ALLOWED=NO`. The build emitted normal Swift compile output but hung during asset catalog processing and timed out after 10 minutes. A partial `.app` bundle existed but did not contain a complete executable payload.

### 21:37 UTC — Generic simulator build workaround

Retried as a generic simulator build and cleared app-icon/accent asset compiler names. This build succeeded and produced `DerivedDataQA2/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`.

### 21:42 UTC — Install and launch

Installed the built app onto the iPhone 17 Pro simulator and launched bundle id `com.bande-a-bonnot.jasonette`. App displayed the Jasonpedia landing page loaded from the configured remote URL.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/001-launch.png`

### 21:44–21:46 UTC — Attempted input driving

Tried to click simulator content using CoreGraphics mouse events posted to the Simulator window and process. Screenshots after attempted taps were unchanged. The harness can read Simulator pixels via `simctl io screenshot`, but the current process does not appear able to inject pointer/touch input into Simulator.

Evidence attempts:

- `docs/qa/artifacts/2026-05-18-ios-simulator/002-after-core-tap.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/003-click-session.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/004-postpid.png`

### 21:46 UTC — Regression suite

Ran `swift test`; result was 439 tests, 0 failures.

## Findings

### F001 — QA blocker: unable to inject simulator touch input from current harness

Severity: blocker for this QA pass  
Status: open  
Area: QA infrastructure / simulator control

#### What happened

The app could be built, installed, launched, and screenshotted in the simulator, but attempts to drive taps from the agent environment did not affect the simulator UI.

Attempted approaches:

- CoreGraphics `.cghidEventTap` mouse events at calculated Simulator window coordinates
- CoreGraphics `.cgSessionEventTap` mouse events
- `CGEvent.postToPid` targeting the Simulator process
- AppleScript/System Events was attempted but timed out while querying Simulator window details

All post-tap screenshots remained on the Jasonpedia landing page.

#### Expected behavior

The QA agent needs a reliable way to tap, swipe, type, and navigate the simulator so it can perform the requested exploratory end-to-end QA pass.

#### Reproduction steps

1. Boot iPhone 17 Pro simulator.
2. Install and launch Jasonette.
3. Capture screenshot — app is visible.
4. Post mouse/touch input to the Simulator window/process from the harness.
5. Capture screenshot again.
6. Observe no UI change.

#### Evidence

- Before input: `docs/qa/artifacts/2026-05-18-ios-simulator/001-launch.png`
- After attempted input: `docs/qa/artifacts/2026-05-18-ios-simulator/002-after-core-tap.png`, `003-click-session.png`, `004-postpid.png`

#### Notes / hypotheses

Likely macOS accessibility/Input Monitoring permissions or the agent harness environment prevents synthetic input from reaching Simulator. A proper pass needs one of:

- an agent/session with GUI input permissions,
- a preinstalled tool such as `idb`, `maestro`, or `applesimutils`/tap support,
- an XCUITest UI-driver target used only as an interaction harness,
- or a human-driven Simulator session while the agent records findings.

### F002 — Device-specific simulator build hung during asset catalog processing

Severity: medium / QA infrastructure  
Status: needs confirmation  
Area: build / simulator

#### What happened

The direct device-specific build for iPhone 17 Pro timed out after 10 minutes around asset catalog compilation. A generic simulator build succeeded afterward when app icon/accent asset compiler settings were cleared on the command line.

#### Expected behavior

The standard simulator build command should complete without requiring asset compiler overrides.

#### Reproduction steps

From `JASONETTE-iOS/JasonetteApp`:

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

#### Evidence

- Build timed out during `CompileAssetCatalogVariant thinned` / related asset handling.
- Successful workaround command is recorded in Environment.

#### Notes / hypotheses

This may be local Xcode 26.2 / simulator-runtime behavior rather than an app bug. Needs confirmation in a normal Xcode GUI build and/or CI.

## Observations

### O001 — App launches and renders the Jasonpedia landing page

The initial remote `demo.json` bootstrap loaded and rendered. Header background is green, title reads “Jasopedia”, and the “View JSON” header button is visible. The body shows Tutorial and Showcase sections with entries such as Core, View, Action, Template, Web Container, Instagram, and Twitter.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/001-launch.png`

### O002 — Launch document does not expose footer tabs on the first screen

The configured `demo.json` landing page does not show a footer tab bar. Footer-tab and action-tab behavior require navigating into Jasonpedia examples or launching a tab-specific fixture directly.

## Non-Issues / Confirmed Working

- App compiled successfully for generic iOS simulator.
- App installed successfully on iPhone 17 Pro simulator.
- App launched successfully.
- Remote bootstrap document rendered successfully.
- Swift regression suite passed: 439 tests, 0 failures.

## Follow-Up Questions

1. Should we add a dedicated UI test/interaction harness target for simulator QA so agents can drive taps without depending on macOS GUI-input permissions?
2. Should the app support a debug launch argument or environment variable for the entry URL? That would make simulator QA of specific Jasonpedia fixtures much easier without code edits.
3. Is the device-specific asset-catalog build hang reproducible for humans in Xcode 26.2, or only in this harness?

## Recommended Next Step

Run this same charter in an environment with working Simulator input control. If we want this to be agent-repeatable, add a lightweight XCUITest target or a debug-only launch-URL override, then perform the full exploratory pass against:

- `Jasonpedia/demo.json`
- `Jasonpedia/core/href/tabs.json`
- action examples under `Jasonpedia/action/`
- component examples under `Jasonpedia/view/component/`
