# iOS Simulator Complete QA Pass — 2026-05-18/19

## Environment

- Date/time: 2026-05-18 21:20 UTC initial setup; continued 2026-05-19 06:38–06:58 UTC with `agent-device`
- Git commit SHA: `51f0d11b245306e4e04740ef2783648969546a66`
- Working tree at start: clean
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Entry URL: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`
- Automation tool that worked: `agent-device` 0.14.9 via `npx --yes agent-device@latest`
- Build/run commands used:
  - Initial device-specific build attempted:
    `xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' -derivedDataPath DerivedDataQA CODE_SIGNING_ALLOWED=NO build`
  - Generic simulator build used after the first build hung:
    `xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedDataQA2 CODE_SIGNING_ALLOWED=NO ASSETCATALOG_COMPILER_APPICON_NAME= ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= build`
  - Install: `xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 DerivedDataQA2/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`
  - Launch: `xcrun simctl launch 61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette`
  - Agent-device launch: `agent-device open com.bande-a-bonnot.jasonette --session jasonetteqa --platform ios --device 'iPhone 17 Pro' --relaunch`
  - Unit/regression suite: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Build result: generic simulator build succeeded; first device-specific build hung during asset catalog processing.
- Test result: 439 tests, 0 failures.
- Local changes: this QA document and screenshot artifacts only.

## Summary

- Overall status: partial but real simulator QA pass completed. The app builds, installs, launches, and the Jasonpedia landing page renders. `agent-device` can drive the simulator through XCTest/accessibility and was used for the exploratory pass after raw CoreGraphics input failed.
- Most serious product finding: Jasonpedia template/list demos that use original Jasonette object-form `items: { "{{#each ...}}": ... }` render as blank/empty tappable areas, making major demo pages unusable.
- Areas tested:
  - App launch / remote bootstrap
  - Push navigation and back navigation
  - Pushed document that declares `footer.tabs`
  - Footer tab rendering/tapping in `core/href/tabs.json`
  - `$util.alert`
  - `$network` demo landing page
  - Template demo landing page
  - Component demos: HTML, map, textfield/secure textfield
  - Existing Swift test suite
- Areas not fully tested / blocked:
  - True action-only footer tab fixture: none found in Jasonpedia; app has no launch-URL override to point at an ad-hoc fixture without code changes.
  - Modal/web/app external handoff flows were only lightly inspected.
  - Pull-to-refresh, background/foreground, rotation, and rapid tap stress were not completed in this pass.

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

### 21:44–21:46 UTC — Raw input driving failed

Tried to click simulator content using CoreGraphics mouse events posted to the Simulator window and process. Screenshots after attempted taps were unchanged. This was a harness/input-permission issue, not a simulator limitation.

Evidence attempts:

- `docs/qa/artifacts/2026-05-18-ios-simulator/002-after-core-tap.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/003-click-session.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/004-postpid.png`

### 06:38 UTC — Switched to `agent-device`

Installed/ran `agent-device` via `npx`. First `snapshot` timed out while the XCTest runner bootstrapped, then a second snapshot succeeded. Re-opened the Jasonette app in the same session and got a usable accessibility tree.

Key command:

```bash
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonetteqa --platform ios --device 'iPhone 17 Pro' --relaunch
```

### 06:41 UTC — Jasonpedia root

Root page rendered with visible buttons: Core, View, Action, Template, Web Container, Instagram, Twitter. Accessibility snapshot exposed these as buttons.

### 06:42 UTC — Core → `$href` → pushed tabs fixture

Navigated Core → `$href` → “Push transition to another Jason View with tabs”. The target page pushed successfully and rendered a footer tab bar with three image-only Mario icons.

Evidence:

- `docs/qa/artifacts/2026-05-18-ios-simulator/005-href-tabs.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/006-after-tab2.png`

Notes:

- The tab buttons are exposed as unlabeled buttons in accessibility.
- Tapping a tab did not visibly push another view. Because all three fixture tabs point at the same URL, I could not prove selected-content switching from content alone.
- The selected-state indicator promised by the recent footer parity work was not visible to me on this icon-only fixture.
- Back from the tabs page returned to the `$href` page; the shell tab bar disappeared on the previous page as expected.

### 06:46 UTC — Action page / alert

Navigated to Action. `$util.alert (basic)` displayed an alert with title “Basic Alert” and an OK button. Dismissal worked.

### 06:47 UTC — Action → `$network`

Navigated to `$network`. Page showed the note/header but the actual list items were blank/absent; accessibility exposed only empty footer/tab-ish buttons and no item titles such as `imagejason`, `eliza`, or `Microblog with user account`.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/007-network-empty-tabs.png`

### 06:50 UTC — View → Component → HTML

Navigated to View → Component → html. Page rendered literal `[Unknown: html]`.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/008-html-component.png`

### 06:51 UTC — View → Component → map

Map page rendered actual map content (MapKit accessibility nodes such as Belgium, Luxembourg, Paris, Munich, Legal). This is better than the handoff’s old “map stub” wording suggests, though deeper pin/region behavior was not verified.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/009-map-component.png`

### 06:53 UTC — Template landing page

Template page rendered section headers (“JSON Templating”, “Non-JSON Templating”) but the actual list entries were blank/empty tappable regions. Expected entries from JSON include Inline Data, Dynamic Data, #each, conditionals, etc.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/010-template-blank-buttons.png`

### 06:55 UTC — Textfield / secure textfield

Plain textfield accepted input. Keyboard return dismissed the keyboard. The secure textfield displayed the entered secret text (`secret123`) visibly and accessibility exposed it as `text-field "secret123"`, not a secure/password field.

Evidence: `docs/qa/artifacts/2026-05-18-ios-simulator/011-secure-field-visible.png`

### 21:46 UTC — Regression suite

Ran `swift test`; result was 439 tests, 0 failures.

## Findings

### F001 — Original Jasonette object-form `items` templates render blank/empty lists

Severity: high  
Status: open  
Area: template rendering / Jasonpedia demos

#### What happened

Several Jasonpedia pages that use original Jasonette template syntax with object-form `items` render as blank tappable areas or missing list entries. The most obvious examples found:

- `Jasonpedia/template/index.json`
- `Jasonpedia/action/network/index.json`

Both use syntax like:

```json
"items": {
  "{{#each json_items}}": {
    "type": "vertical",
    "href": { "url": "{{url}}" },
    "components": [...]
  }
}
```

In the app, the section headers render, but generated item labels such as “Inline Data”, “Dynamic Data”, “imagejason”, and “eliza” do not render.

#### Expected behavior

`{{#each ...}}` under `items` should produce an array of rendered components/items, visible and tappable.

#### Reproduction steps

1. Launch app.
2. Tap `Template` from Jasonpedia root.
3. Observe only section headers and blank content areas where entries should appear.
4. Return to root.
5. Tap `Action` → `$network`.
6. Observe only the note/header; network demo entries are missing.

#### Evidence

- Template: `docs/qa/artifacts/2026-05-18-ios-simulator/010-template-blank-buttons.png`
- Network: `docs/qa/artifacts/2026-05-18-ios-simulator/007-network-empty-tabs.png`

#### Notes / hypotheses

The Swift renderer likely decodes/rendered `section.items` only as `[JasonComponent]`, while original Jasonette allows object-form directive expansion under array-valued fields. This is a major compatibility gap for Jasonpedia and will hide many demos.

### F002 — Secure textfield displays entered secret as plain text

Severity: high  
Status: open  
Area: components / text input / privacy

#### What happened

The “secure” textfield on the textfield component demo accepts text but displays and exposes it as plain text. After entering `secret123`, the accessibility snapshot showed `text-field "secret123" [editable]`.

#### Expected behavior

A secure textfield should use secure entry (`SecureField` on SwiftUI), mask the entered value visually, and avoid exposing the plain text as a normal text field value.

#### Reproduction steps

1. Launch app.
2. Tap `View` → `Component` → `textfield`.
3. Fill the `secure` field with `secret123`.
4. Observe the secret appears visibly/unmasked and is exposed in accessibility as a normal text field.

#### Evidence

- `docs/qa/artifacts/2026-05-18-ios-simulator/011-secure-field-visible.png`

#### Notes / hypotheses

This matches the handoff’s existing Phase C item (“secure textfield (`SecureField`)”), but it is user-visible and privacy-sensitive.

### F003 — HTML component renders as `[Unknown: html]`

Severity: medium  
Status: open  
Area: components / HTML

#### What happened

The HTML component demo renders literal placeholder text `[Unknown: html]`.

#### Expected behavior

The HTML component should render HTML content, likely via `WKWebView` or a native rich text bridge depending on the spec target.

#### Reproduction steps

1. Launch app.
2. Tap `View` → `Component` → `html`.
3. Observe `[Unknown: html]`.

#### Evidence

- `docs/qa/artifacts/2026-05-18-ios-simulator/008-html-component.png`

#### Notes / hypotheses

This matches the handoff’s Phase C gap (“HTML component (`WKWebView`)”).

### F004 — Footer tab bar icon-only items have poor accessibility and unclear selected state

Severity: medium  
Status: open / needs confirmation  
Area: tabs / accessibility / visual state

#### What happened

The `core/href/tabs.json` fixture renders three image-only footer tabs. Accessibility exposes them as unlabeled buttons (`@e21`, `@e22`, `@e23` with no label), and I could not see a clear selected-state indicator in the screenshot.

#### Expected behavior

Each tab should expose a useful accessibility label when possible (from text, URL/title fallback, or author-provided label), and selected state should be visually obvious even when the tab has only an icon and no text.

#### Reproduction steps

1. Launch app.
2. Tap `Core` → `$href` → `Push transition to another Jason View with tabs`.
3. Inspect footer tabs / accessibility snapshot.
4. Tap a tab.
5. Observe three unlabeled tab buttons and unclear selected state.

#### Evidence

- `docs/qa/artifacts/2026-05-18-ios-simulator/005-href-tabs.png`
- `docs/qa/artifacts/2026-05-18-ios-simulator/006-after-tab2.png`

#### Notes / hypotheses

This may be partly fixture-related (icon-only tabs with no text), but a tab bar should still avoid unlabeled controls. The selected indicator added in code may be clipped, too subtle, or hidden below the icon-only cell in this fixture.

### F005 — Device-specific simulator build hung during asset catalog processing

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

### O002 — `$util.alert` works for the basic alert demo

The Action → `$util.alert (basic)` demo displayed a native alert with expected title/body and an OK dismissal button.

### O003 — Pushed document with footer tabs does not duplicate the previous page’s footer

After navigating to the tabs fixture, the footer tab bar appears on that pushed page. Pressing the visible back button returns to the previous `$href` page and the tab bar disappears. This matches the structural rule that shell-mounted tabs belong to the current document scope.

### O004 — Map demo renders actual map content

The map demo displayed map accessibility nodes and not just a placeholder. Pin/region semantics were not verified.

### O005 — The “AgentDeviceRunner…” breadcrumb in screenshots is a QA harness artifact

Screenshots taken while `agent-device` drives the simulator show an iOS status-bar breadcrumb back to `AgentDeviceRunner...`. This is expected when XCTest/runner automation launches or foregrounds the app and is not itself an app bug.

## Non-Issues / Confirmed Working

- App compiled successfully for generic iOS simulator.
- App installed successfully on iPhone 17 Pro simulator.
- App launched successfully.
- Remote bootstrap document rendered successfully.
- Basic push navigation worked.
- Visible back navigation worked.
- Basic alert action worked.
- Plain textfield accepted text input.
- Keyboard return dismissed the keyboard in the tested textfield.
- Swift regression suite passed: 439 tests, 0 failures.

## Follow-Up Questions

1. Should we add `agent-device` usage notes to project docs for repeatable simulator QA?
2. Should the iOS app support a debug launch argument or environment variable for the entry URL? That would make simulator QA of specific Jasonpedia fixtures and ad-hoc action-tab fixtures much easier without code edits.
3. Should original Jasonette object-form `items` template directives be treated as P1/P2 compatibility work? They block high-value Jasonpedia demos.
4. Is the device-specific asset-catalog build hang reproducible for humans in Xcode 26.2, or only in this harness?

## Recommended Follow-Up Tickets

1. Support object-form template directives under array fields such as `sections[].items`.
2. Implement secure textfield rendering with `SecureField` / secure text entry semantics.
3. Implement HTML component rendering.
4. Improve footer tab accessibility labels and verify selected indicator on icon-only tabs.
5. Add a debug launch-URL override for simulator QA.
