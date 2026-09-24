# iOS Luna QA Pass — 2026-09-24

## Environment

- Checkout: `2255ed4877485686f4c4fd7f35cc926198b67d0f`
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator target: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`; `simctl list devices available` reported `Booted`
- Bundle ID: `com.bande-a-bonnot.jasonette`
- Fresh Debug Simulator build: `/private/tmp/JasonetteIOSQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`; built from this checkout and installed for this pass
- `agent-device`: cached CLI 0.17.4; default-sandbox attach failed, while an escalated attach succeeded but its snapshot timed out
- Artifact directory: `docs/qa/artifacts/2026-09-24-ios-luna-qa-pass/`

## Commands and results

From `JASONETTE-iOS/JasonetteApp`:

```bash
swift test
```

The first default-sandbox invocation failed before compiling because Swift's
Clang module cache under `/Users/thomas/.cache/clang/ModuleCache` was not
accessible. Retried with the toolchain cache access allowed. Result: **PASS**,
612 tests, 0 failures (15.022 seconds test execution). Relevant fixture and
action coverage included Jasonpedia textarea rendering, secure textfield route,
HTML and Map component selection, geo payload-to-render chaining, scanner
fallback and success paths, state/action dispatch, and navigation model paths.
This is package-level evidence; it does not establish simulator UI behavior.

```bash
xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/JasonetteIOSQA \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build
```

Result: **PASS** (`** BUILD SUCCEEDED **`). Xcode startup and compilation took
about 20 minutes on this host. Initial shorter device-specific build attempts
were stopped before Xcode emitted diagnostics; the successful generic simulator
build above supersedes those attempts.

Install and direct-entry launch:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  /private/tmp/JasonetteIOSQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textarea/index.json
```

The direct-entry launch returned PID `86641`. The first capture at
`textarea.png` showed the initial white loading surface; the delayed capture
`textarea-delayed.png` rendered the screen after the remote fixture finished
loading. A second launch and capture at `textarea-current-repeat.png` reproduced
the same rendered layout and the same button text truncation.

The first cached automation attach, run in the default sandbox, was:

```bash
/Users/thomas/.npm/_npx/d03929938e601151/node_modules/.bin/agent-device open \
  com.bande-a-bonnot.jasonette --session jasonetteqa --platform ios \
  --device 'iPhone 17 Pro'
```

Result: **INCONCLUSIVE / tooling**. It returned
`COMMAND_FAILED: Failed to start daemon` before establishing a session. A
second attempt with simulator access allowed established session
`01a0d23c-6f2e-77ef-934d-5f56519ad0ee` in about 79 seconds. Its
`snapshot -i` request then hit the CLI's fixed 90-second daemon timeout
(Diagnostic ID `muf6xg1v-cedb2998`). No accessibility snapshot or touch controls
were returned. Interactive taps, text entry, navigation, and native action
presentation therefore could not be exercised.

Screenshots were captured with:

```bash
xcrun simctl io 61EA0147-56E4-4399-8D51-F98A93B708A6 screenshot <artifact.png>
```

## Screen results

### Textarea input fixture — PARTIAL PASS; verified button truncation

Fixture: `Jasonpedia/view/component/textarea/index.json`.

The textarea screen rendered its heading, bordered empty textarea, `Enter text`
placeholder, and Done control. The screen was captured twice from separate
direct-entry launches. Both current-build captures render the authored `Done`
button as `Do...`; the earlier 2026-05-31 capture shows the full label. Expected:
the authored label remains legible within the specified 60-point width. Actual:
the label truncates. This is a verified **P3** visual regression, supported by
the two current screenshots, the historical screenshot, and the focused source
check: `ButtonComponent` applies 14 points of horizontal padding before the
style modifier applies the fixed 60-point frame. See
`todos/103-fix-ios-fixed-width-button-label-truncation.md`.

Evidence:

- `docs/qa/artifacts/2026-09-24-ios-luna-qa-pass/textarea-delayed.png`
- `docs/qa/artifacts/2026-09-24-ios-luna-qa-pass/textarea-current-repeat.png`
- `docs/qa/artifacts/2026-05-31-ios-textarea-affordance/textarea-empty-affordance.png`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/ButtonComponent.swift`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/JasonStyleModifier.swift`

The blank initial capture was a loading state while the remote fixture was
fetching; the delayed screen rendered normally. Input editing and the Done
action were not exercised because interactive automation did not establish a
session.

### Geo state/action fixture — initial render PASS; action INCONCLUSIVE

Fixture: `Jasonpedia/action/geo/index.json`.

The screen rendered the `$geo` heading and the Display and Map controls in the
expected initial layout (`geo.png`). Tapping either control, granting location,
and observing the resulting coordinate/map state were not possible without an
automation session. The action chain is therefore **INCONCLUSIVE** at simulator
UI level. Package tests for the geo payload and success-render chain passed.

### HTML component fixture — PASS

Fixture: `Jasonpedia/view/component/html/index.json`.

The direct-entry screen rendered its HTML heading, image, article text, and
links (`html.png`). Interactive link behavior was not tested.

## Coverage matrix

| Path | Result | Evidence / limit |
| --- | --- | --- |
| Swift package suite | **PASS** | 612 tests, 0 failures; command above |
| Textarea layout | **PARTIAL PASS / verified P3 finding** | Screen renders; fixed-width `Done` text truncates in two current captures |
| Geo fixture initial rendering | **PASS** | Display/Map controls render; tap-driven geo action chain not exercised |
| HTML component | **PASS** | HTML heading, image, body text, and links render |
| Component decoding/render routing (secure textfield, Map) | **PASS at unit/fixture level** | Relevant ViewModel and component dispatch tests passed; no simulator UI observation in this pass |
| State and action chains (geo, scan, alerts, utility actions) | **PASS at unit/fixture level** | Relevant ActionDispatcher and Jasonpedia fixture tests passed; no interactive simulator run |
| Navigation/tab interaction | **INCONCLUSIVE** | Model-level navigation tests passed; simulator interaction unavailable |
| Native capability presentation | **INCONCLUSIVE** | No permission prompt or native sheet was interacted with |
| Debug simulator build and launch | **PASS** | Generic Debug simulator build succeeded; installed and launched on iPhone 17 Pro |

## Findings and follow-ups

One verified P3 UI regression was found: the 60-point textarea Done button
truncates after default horizontal padding was added. A matching todo draft was
created. Other simulator coverage limits were the slow remote fixture load,
the default-sandbox `agent-device` daemon startup failure, and the escalated
snapshot timeout. These limits do not affect the
successful build, screenshot evidence, or passing package suite.

## Not tested

- Touch-driven tab/navigation flows and text input
- Geo success/error action interaction and resulting native location UI
- Scanner/camera/contacts prompts or native share sheets
- HTML link interaction
