# iOS Tab Navigation Chrome ZStack QA — 2026-05-29

## Summary

Investigated the speculative SwiftUI issue where multiple mounted `NavigationStack`s
inside `JasonetteTabShell`'s `ZStack` could let a hidden tab's navigation title or
toolbar override the selected tab's chrome.

Result: after changing the shell to render the selected tab last in the ZStack,
Simulator QA confirmed the visible tab keeps its own title and toolbar after
switching across three mounted tabs and after returning from a tab with a pushed
child page.

## Environment

- Repo base before this todo: `ccf4e49`
- Change under test: selected-last `JasonetteTabShell` ZStack ordering plus local
  chrome fixtures in this todo change
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- App: Debug `com.bande-a-bonnot.jasonette`
- Entry URL: `http://127.0.0.1:8765/chrome-index.json`

## Fixture

Local HTTP fixture files under `docs/qa/fixtures/ios-simulator-tabs/`:

- `chrome-index.json` — Home tab, title `Chrome Home`, toolbar button `Home Menu`, link to `chrome-home-detail.json`
- `chrome-detail.json` — Detail tab, title `Chrome Detail`, toolbar button `Detail Menu`, link to `chrome-detail-child.json`
- `chrome-third.json` — Third tab, title `Chrome Third`, toolbar button `Third Menu`
- `chrome-home-detail.json` — pushed Home page, title `Home Pushed`, toolbar button `Pushed Menu`
- `chrome-detail-child.json` — pushed Detail page, title `Detail Pushed`, toolbar button `Child Menu`

## Commands

```bash
jq empty docs/qa/fixtures/ios-simulator-tabs/chrome-*.json

cd JASONETTE-iOS/JasonetteApp
swift test --filter TabNavigationCoordinatorTests
swift test
swift build
mise exec -- tuist generate --no-open
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  build

python3 -m http.server 8765 --directory docs/qa/fixtures/ios-simulator-tabs
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  JASONETTE-iOS/JasonetteApp/DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL http://127.0.0.1:8765/chrome-index.json

npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session tabchrome \
  --platform ios \
  --device "iPhone 17 Pro"
npx --yes agent-device@latest snapshot -i --session tabchrome --platform ios
```

The first `agent-device snapshot` timed out while the runner started; retrying
succeeded, matching the known operational note in `docs/qa/README.md`.

## Flow and Results

1. **Initial Home tab**
   - Snapshot page/other/nav title: `Chrome Home`
   - Visible toolbar button: `Home Menu`
   - Footer tabs: Home, Detail, Third

2. **Switch Home → Detail**
   - Active page title: `Chrome Detail`
   - Active toolbar button: `Detail Menu`
   - Captured screenshot: `artifacts/2026-05-29-ios-tab-chrome/detail-selected.png`

3. **Switch Detail → Third**
   - Active page title: `Chrome Third`
   - Active toolbar button: `Third Menu`
   - Captured screenshot: `artifacts/2026-05-29-ios-tab-chrome/third-selected.png`

4. **Switch Third → Detail, then push Detail child**
   - Pushed page showed title `Detail Pushed`
   - Back button label preserved the parent tab title `Chrome Detail`
   - Active toolbar button: `Child Menu`
   - Captured screenshot: `artifacts/2026-05-29-ios-tab-chrome/detail-pushed.png`

5. **Switch pushed Detail tab → Home**
   - Active page title restored to `Chrome Home`
   - Active toolbar button restored to `Home Menu`
   - Captured screenshot: `artifacts/2026-05-29-ios-tab-chrome/home-restored-after-push.png`

## Findings

- No visual navigation title or toolbar override was observed after tab switches.
- Rendering the selected tab last keeps the selected tab's `NavigationStack`
  last-mounted in the ZStack without mutating the authored footer tab order.
- `agent-device` accessibility snapshots still list mounted hidden tabs' navigation
  bars and content after they have been selected once. Screenshots confirmed only
  the selected tab's chrome is visually active. This is worth remembering for
  future accessibility-focused QA, but it did not reproduce the visual title/
  toolbar collision this todo targeted.

## Not Tested

- Large-title behavior: `JasonetteView` currently forces
  `.navigationBarTitleDisplayMode(.inline)` on iOS, so there is no authored
  large-title path to exercise in this renderer.
