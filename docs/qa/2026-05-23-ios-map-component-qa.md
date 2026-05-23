# iOS Simulator QA — Map Component Pins and Region

Date: 2026-05-23

## Environment

- Commit at QA start: `15c9f5d`
- macOS: 26.2 (25C56)
- Xcode: 26.2 (17C52)
- Simulator: iPhone 17 Pro, iOS 26.2 (`61EA0147-56E4-4399-8D51-F98A93B708A6`)
- App bundle: `com.bande-a-bonnot.jasonette`

## Build and Test Commands

```bash
cd JASONETTE-iOS/JasonetteApp
swift test
xcodebuild -workspace Jasonette.xcworkspace \
  -scheme Jasonette-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  -derivedDataPath DerivedData build
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
xcrun simctl launch booted com.bande-a-bonnot.jasonette
xcrun simctl io booted screenshot <path>.png
```

`agent-device` 0.15.2 was attempted for interaction/snapshots, but its XCTest runner timed out in this pass. Visual confirmation used `xcrun simctl io booted screenshot`.

## Entry Documents

1. Hosted Jasonpedia fixture, temporarily used as app entry during QA:
   - `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/map/index.json`
2. Local pin-focused fixture served only for simulator QA:
   - `docs/qa/artifacts/2026-05-23-ios-map-component/map-pin-fixture.json`
   - Served at `http://127.0.0.1:8765/map-pin-fixture.json`

`Sources/JasonetteApp-iOS/App.swift` was restored to the normal `demo.json` entry after screenshot capture.

## Evidence

- `docs/qa/artifacts/2026-05-23-ios-map-component/map-fixture.png`
  - Confirms the Jasonpedia map fixture renders native Apple maps for the header map and the `200x200` region section instead of the prior blank/stub placeholder.
- `docs/qa/artifacts/2026-05-23-ios-map-component/map-pin-fixture.png`
  - Confirms authored pin rendering and the `style.selected` callout path: red pin marker plus visible title/description bubble (`This is a pin`, `It really is.`).

## Result

PASS.

Confirmed:

- `type: "map"` renders an actual map.
- Authored `region.coord`, `region.width`, and `region.height` produce a centered/zoomed map.
- Authored `pins` produce visible pin annotations.
- Authored pin `style.selected` produces an initially visible callout-like label.

## Notes

- This QA did not cover live user location or map style modes; those were outside `todos/045` scope.
- A debug launch URL override would avoid temporary app-entry edits for future fixture-specific QA (`todos/043`).
