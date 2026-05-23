# iOS Simulator QA — HTML Component — 2026-05-23

## Scope

Visual QA for `todos/041` after `0474833 Render HTML components with WebKit`.

## Environment

- Date/time: 2026-05-23 UTC
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- App bundle id: `com.bande-a-bonnot.jasonette`
- Commit under test: `0474833 Render HTML components with WebKit`
- Unit/regression suite before simulator pass: `462 tests, 0 failures`

## Build / Install

Built the SwiftUI Tuist-generated iOS app from `JASONETTE-iOS/JasonetteApp`:

```bash
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataHTMLQA \
  CODE_SIGNING_ALLOWED=NO \
  ASSETCATALOG_COMPILER_APPICON_NAME= \
  ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= \
  build
```

Then installed/launched with:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  DerivedDataHTMLQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette
```

## Method

Because the app still lacks a debug launch URL override (`todos/043`), targeted
fixture QA was performed by temporarily changing the hardcoded launch URL in
`Sources/JasonetteApp-iOS/App.swift` to:

```text
https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/html/index.json
```

The app was rebuilt, installed, launched, and captured with `xcrun simctl io ...
screenshot`. The source URL was restored to `Jasonpedia/demo.json` afterward; no
`App.swift` source diff remains.

## Evidence

Fixture URL:

- `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/html/index.json`

Screenshot:

- `docs/qa/artifacts/2026-05-23-ios-html-qa/001-html-component-post-fix.png`

Observed:

- The HTML component page loads with title `HTML` and the `View JSON` header action.
- The Jasonpedia article image renders inside the page.
- Styled paragraph text renders below the image.
- Links render as links (blue/underlined), including `blog post announcing the release` and `Continue reading...`.
- The old `[Unknown: html]` placeholder is not present.
- The initial viewport shows a sane embedded WebKit height; content does not collapse to zero height.

## Outcome

`todos/041` is visually confirmed fixed for the Jasonpedia HTML component demo.

## Follow-ups

- `todos/043`: add a debug launch URL override so future fixture QA does not require temporary source edits.
- `todos/044`: continue tracking the simulator/asset-catalog build timeout; the generic simulator build workaround remained successful for this pass.
