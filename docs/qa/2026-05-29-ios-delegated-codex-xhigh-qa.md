# iOS Delegated Codex xhigh Simulator QA — 2026-05-29

## Environment

- Date/time: 2026-05-29 22:48–23:17 UTC delegated exploration; 23:20–23:30 UTC follow-up fixes/verification
- Commit initially under test: `8da3ff6fec888aea0458b69638a98a7e0956e79e`
- App bundle: `com.bande-a-bonnot.jasonette`
- Entry URL: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Automation: `agent-device` 0.16.4 via `npx --yes agent-device@latest`, session `jasonetteqa`
- Delegated agent: `pi --provider openai-codex --model gpt-5.3-codex --thinking xhigh`
- Delegated session log: `/Users/thomas/.pi/agent/sessions/--Users-thomas-Projects-Banade-a-Bonnot-JASONETTE-Reborn--/2026-05-29T22-48-44-842Z_019e75ec-f82a-7879-86de-40e89c015129.jsonl`
- Artifacts: `docs/qa/artifacts/2026-05-29-delegated-agent/`

## Setup commands

The app was built, installed, and launched on the booted simulator:

```bash
cd JASONETTE-iOS/JasonetteApp
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

Note: `agent-device`'s first-run Xcode runner startup was slow under Xcode 26. The local `npx` cache copy was patched during setup to extend startup/request timeouts, after which `agent-device@latest` worked reliably in session `jasonetteqa`.

## Summary

A separate Codex xhigh agent drove the already-installed iOS Simulator app with `agent-device` and explored Jasonpedia broadly. The delegated run timed out before writing its report, but the session log and screenshots show useful coverage across root navigation, core links, components, footers, and actions.

Important results:

- Most core renderer areas checked in this pass are working: Jasonpedia root, View JSON web handoff, Core list and push navigation, label/image/html/map/textfield/secure textfield components, footer tabs, and `$util.alert (basic)`.
- A real app-level issue was found and fixed in follow-up: footer input right buttons that use named action triggers (`"action": { "trigger": "send" }`) did not execute, and alert option strings such as `{{$get.message}}` were not interpolated from local state.
- Textarea coverage showed the blank textarea fixture has weak visual/accessibility affordance until focused; after follow-up, direct input was verified and the focused `TextEditor` exposes as a `text-view`.
- The external/demo `$network` → `eliza` flow still fails with a warning: `The data couldn’t be read because it isn’t in the correct format.` Retry did not recover.

## Areas tested

- Jasonpedia root page load and primary buttons
- Header `View JSON` web handoff to GitHub
- Core → `$href` push navigation and back navigation
- View → Component demos:
  - label
  - image
  - html
  - map
  - slider (visible; tap did not change value through the harness)
  - textfield and secure textfield
  - textarea
  - button landing/page
- View → Footer demos:
  - chat/input footer
  - tabs footer, including Top Secret/Info tab taps and close navigation
- Action demos:
  - `$util.alert (basic)`
  - `$util.toast` tap smoke check (known stub/no visible behavior)
  - `$network` landing page and `eliza` child
  - local variable textfield/textarea binding smoke check

Not fully covered: media/camera/photo picker permissions, barcode/vision, geo permission flow, audio playback, template section deep pass, web container deep pass, rotation/backgrounding/performance stress.

## Findings and follow-up

### F001 — Footer input named action triggers did not execute before follow-up fix

- Severity: P1/P2 app behavior gap
- Status: fixed in follow-up working tree after delegated QA
- Evidence before fix: `docs/qa/artifacts/2026-05-29-delegated-agent/footer-input-no-alert.png`
- Evidence after fix: `docs/qa/artifacts/2026-05-29-delegated-agent/footer-input-alert-after-fix.png`

#### Reproduction before fix

1. Launch Jasonpedia demo.
2. Navigate `View` → `Footer` → `Chat Input`.
3. Type text in the footer input.
4. Tap `Send`.

Expected: `Send` runs the named `send` action from `head.actions`, displaying a `$util.alert` titled `Message` with the current footer input value.

Actual before fix: no alert appeared after repeated taps; the footer remained on the input page.

#### Root cause

The fixture uses original Jasonette named-action syntax:

```json
"right": {
  "text": "Send",
  "action": { "trigger": "send" }
}
```

`JasonAction` decoded `type/options/success/error` only, so `trigger` was discarded/no-op. Even after dispatching the named action, the alert description needed `{{$get.message}}` interpolation against local state.

#### Fix

- Added `JasonAction.trigger` decoding.
- Added an `ActionDispatcher` named-action resolver and wired it to the active document's `head.actions` in `JasonetteViewModel`.
- Render `$util.alert` title/description option strings through `TemplateEngine` with both direct local state and `$get`/`$cache` context.
- Added `ActionDispatcherTests` coverage for named trigger execution and `{{$get.message}}` alert interpolation.

#### Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests` — 36 tests passed.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 504 tests passed.
- Device-specific simulator `xcodebuild` succeeded.
- Reinstalled/launched the fixed Debug app, launched direct fixture `Jasonpedia/view/footer/input.json`, typed in the footer input, tapped `Send`, and observed alert title `Message` with the typed value.

### F002 — Textarea fixture has weak empty-state affordance; focused textarea accepts input

- Severity: P2 usability/accessibility follow-up
- Status: partially improved/verified; consider a visual affordance follow-up
- Evidence before follow-up: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea.png`
- Evidence after follow-up focus/input: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea-after-fix-typed.png`

The delegated pass saw `View` → `Component` → `textarea` render as a mostly blank page with only the section label and `Done` button visible; the initial accessibility snapshot exposed the horizontal row as scroll views and a `Done` button, not a `text-view`.

Follow-up added a minimum width to `TextAreaComponent` and verified the direct fixture can receive text by focusing the textarea coordinate, typing, dismissing the keyboard, and observing a focused `text-view` in the accessibility snapshot.

Remaining concern: the empty textarea is still visually subtle because it has no border/placeholder in this fixture and the page is mostly white. A dedicated follow-up could make empty textareas visibly tappable without relying on coordinate focus.

### F003 — `$network` → `eliza` demo returns a parse warning

- Severity: P2/P3 demo/API compatibility issue
- Status: open
- Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/action-network-eliza-warning.png`

#### Reproduction

1. Launch Jasonpedia demo.
2. Navigate `Action` → `$network`.
3. Tap `eliza, make a $network.request to node.js express based chatbot server...`.
4. Wait for the child page to load.
5. Tap `Retry`.

Expected: the Eliza/chatbot demo loads or displays a useful demo-specific error.

Actual: the app shows `Warning` with `The data couldn’t be read because it isn’t in the correct format.` Retry repeats the same warning.

This may be external demo-server drift, a non-JSON response shape, or a fixture/parser mismatch. It was not fixed in this pass.

## Confirmed working / non-issues

- Jasonpedia root loaded with expected Tutorial/Showcase content and buttons.
- `View JSON` opened GitHub in a web sheet and displayed `Jasonpedia/demo.json` source.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/view-json-result-fallback.png`
- Core list rendered meaningful rows.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/core-list.png`
- Core `$href` push/back navigation worked for the basic push demo.
- Component image fixture rendered an image and labels.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/component-image.png`
- Component HTML fixture rendered as `HTML content` rather than `[Unknown: html]`.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/component-html.png`
- Component map fixture rendered native map content and pins/POI accessibility nodes.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/component-map.png`
- Plain textfield accepted input; secure textfield masked input and exposed `securetextfield` with bullets.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textfield-secure.png`
- Footer tabs displayed and the modal/shell close returned to footer examples.
  - Evidence: `docs/qa/artifacts/2026-05-29-delegated-agent/footer-tabs-info-selected.png`, `docs/qa/artifacts/2026-05-29-delegated-agent/footer-tabs-topsecret-selected.png`
- `$util.alert (basic)` displayed a native alert and `OK` dismissed it.
- Local variables page propagated textfield input to the textarea binding in the same document.

## Verification commands run after fixes

```bash
cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests
cd JASONETTE-iOS/JasonetteApp && swift test
cd JASONETTE-iOS/JasonetteApp && xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  build
```
