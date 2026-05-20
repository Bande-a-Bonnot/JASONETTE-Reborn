# iOS Simulator Post-Fix QA — 2026-05-20

## Scope

Post-fix visual QA for:

- `todos/039` — object-form `items`/`{{#each}}` template lists
- `todos/040` — secure textfield renderer-path fix

## Environment

- Date/time: 2026-05-20 UTC
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- App bundle id: `com.bande-a-bonnot.jasonette`
- Commits under test:
  - `ee81808 Fix object-form each item context`
  - `570f84d Render secure textfields securely`
- Unit/regression suite before simulator pass: `452 tests, 0 failures`

## Build / Install

Built the SwiftUI Tuist-generated iOS app from `JASONETTE-iOS/JasonetteApp`:

```bash
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataQA4 \
  CODE_SIGNING_ALLOWED=NO \
  ASSETCATALOG_COMPILER_APPICON_NAME= \
  ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= \
  build
```

Then installed/launched with:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  DerivedDataQA4/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette
```

## Method

Because the app still lacks a debug launch URL override (`todos/043`), targeted fixture screenshots were captured by temporarily changing the hardcoded URL in `Sources/JasonetteApp-iOS/App.swift`, rebuilding, installing, launching, and then restoring the original URL. No source change was left behind.

`agent-device` was attempted for accessibility-driven navigation, but the runner build timed out on this machine/device during `CompileAssetCatalogVariant thinned`, matching the known simulator/asset-catalog issue tracked in `todos/044`.

Successful post-fix evidence was therefore captured with `xcrun simctl io ... screenshot`.

## Evidence

### Launch still renders Jasonpedia root

Screenshot:

- `docs/qa/artifacts/2026-05-20-ios-simulator/001-post-fixes-launch.png`

Observed:

- Jasonpedia root loaded successfully.
- Root entries such as Core, View, Action, Template, Web Container, Instagram, and Twitter are visible.

### Template list regression fixed

Fixture URL:

- `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/template/index.json`

Screenshot:

- `docs/qa/artifacts/2026-05-20-ios-simulator/002-template-post-fix.png`

Observed visible entries:

- Inline Data
- Dynamic Data
- #each
- #if | #elseif | #else
- Use Javascript expressions
- Javascript function example
- HTML
- RSS
- CSV

Result:

- The blank-list regression from the 2026-05-18/19 QA pass is visually fixed for the Template page.

### `$network` list regression fixed

Fixture URL:

- `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/network/index.json`

Screenshot:

- `docs/qa/artifacts/2026-05-20-ios-simulator/003-network-post-fix.png`

Observed visible entries:

- imagejason
- eliza
- Microblog with user account

Result:

- The blank-list regression from the 2026-05-18/19 QA pass is visually fixed for the `$network` landing page.

### Textfield fixture loads with secure field

Fixture URL:

- `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textfield/index.json`

Screenshot:

- `docs/qa/artifacts/2026-05-20-ios-simulator/004-textfield-secure-post-fix.png`

Observed:

- The textfield fixture loads.
- The secure field is visible as the second text input.

Result:

- Structural/unit coverage confirms this fixture's secure field now routes through `SecureField`.
- Full typed-secret visual/accessibility confirmation is still pending because `agent-device` could not complete snapshot/interaction setup on this simulator due the runner asset-catalog timeout.

## Outcome

- `todos/039`: visually confirmed fixed for the two QA-blocking Jasonpedia pages.
- `todos/040`: code path is unit-covered and the fixture loads; typed-secret simulator confirmation remains pending until `agent-device`/input automation is working again or `todos/043` makes direct fixture QA easier.

## Follow-ups

- `todos/043`: add debug launch URL override to avoid temporary source edits for fixture QA.
- `todos/044`: investigate device-specific asset-catalog timeout, now reproduced with the `agent-device` runner as well as the app build path from the original QA pass.
