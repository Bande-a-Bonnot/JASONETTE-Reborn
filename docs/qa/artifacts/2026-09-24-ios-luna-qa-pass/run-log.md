# Run log — 2026-09-24 iOS Luna QA

- Checkout: `2255ed4877485686f4c4fd7f35cc926198b67d0f`
- macOS: 26.2, build 25C56
- Xcode: 26.2, build 17C52
- Target: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- `swift test`: PASS, 612 tests, 0 failures; suite execution 15.022 seconds
- First sandboxed SwiftPM invocation failed before compilation because its
  Clang module cache under `/Users/thomas/.cache/clang/ModuleCache` was not
  accessible. Rerun with toolchain cache access passed.
- First Tuist and device-specific build attempts stalled during Xcode startup;
  they were superseded by the successful generic Simulator build below.

Successful app build, from `JASONETTE-iOS/JasonetteApp`:

```bash
xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/JasonetteIOSQA \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build
```

Result: exit 0, `** BUILD SUCCEEDED **`. App bundle:
`/private/tmp/JasonetteIOSQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`.

Install:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  /private/tmp/JasonetteIOSQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
```

Install exited 0 after approximately 2m40s.

Direct-entry launches:

```bash
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textarea/index.json

xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/geo/index.json

xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/html/index.json
```

All returned process IDs. Remote fixture loading was slow; the first textarea
capture showed the loading surface, and a delayed capture rendered the page.

Screenshots were captured with:

```bash
xcrun simctl io 61EA0147-56E4-4399-8D51-F98A93B708A6 screenshot <artifact.png>
```

Saved: `textarea.png` (loading surface), `textarea-delayed.png`,
`textarea-current-repeat.png`, `geo.png`, and `html.png`.

Simulator app log capture:

```bash
xcrun simctl spawn 61EA0147-56E4-4399-8D51-F98A93B708A6 log show \
  --last 5m --style compact --predicate 'process == "Jasonette_iOS"'
```

The log contained only its column header and no app process entries.

Cached `agent-device` attach attempt (default sandbox, no session established):

```bash
/Users/thomas/.npm/_npx/d03929938e601151/node_modules/.bin/agent-device open \
  com.bande-a-bonnot.jasonette --session jasonetteqa --platform ios \
  --device 'iPhone 17 Pro'
```

Result: exit 1, `COMMAND_FAILED: Failed to start daemon`. Interactive control
was unavailable in this default-sandbox attempt.

An escalated retry established session
`01a0d23c-6f2e-77ef-934d-5f56519ad0ee` in about 79 seconds. The follow-up
`agent-device snapshot -i --session 01a0d23c-6f2e-77ef-934d-5f56519ad0ee --platform ios --udid 61EA0147-56E4-4399-8D51-F98A93B708A6` reached the
fixed 90-second daemon request timeout (Diagnostic ID `muf6xg1v-cedb2998`). No
accessibility tree or touch controls were returned. This confirms the current
host's known XCTest/daemon interaction limit; simulator screenshots were still
captured with `simctl`.
