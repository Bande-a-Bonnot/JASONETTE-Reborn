# iOS Textarea Empty Affordance QA — 2026-05-31

## Environment

- Date: 2026-05-31
- Commit under test: working tree after `26fa709`
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Fixture: `Jasonpedia/view/component/textarea/index.json`
- Artifact directory: `docs/qa/artifacts/2026-05-31-ios-textarea-affordance/`

## Change under test

Empty textareas now render with a default visible affordance even when the JSON
fixture does not author a placeholder:

- fallback placeholder text: `Enter text`
- visible rounded border
- platform text-background fill
- minimum width/height retained
- accessibility label on the `TextEditor` using authored placeholder when
  present, otherwise a name-based fallback such as `blank text area`
- existing `TextEditor` state binding and keyboard Done toolbar retained

## Commands

```bash
cd JASONETTE-iOS/JasonetteApp && swift test --filter ComponentDispatchTests/testTextArea
cd JASONETTE-iOS/JasonetteApp && swift test --filter ViewModelTests/testJasonpediaTextareaFixtureUsesDefaultEmptyAffordance
cd JASONETTE-iOS/JasonetteApp && swift test
cd JASONETTE-iOS/JasonetteApp && swift build
cd JASONETTE-iOS/JasonetteApp && xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  JASONETTE-iOS/JasonetteApp/DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
python3 -m http.server 8767 --directory Jasonpedia
ENTRY_URL="http://127.0.0.1:8767/view/component/textarea/index.json"
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"
xcrun simctl io \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  screenshot docs/qa/artifacts/2026-05-31-ios-textarea-affordance/textarea-empty-affordance.png
```

## Result

The direct-entry fixture renders a clearly tappable empty textarea with a rounded
border and the `Enter text` placeholder before focus. The `Done` button remains
visible beside the textarea.

Screenshot evidence:
`docs/qa/artifacts/2026-05-31-ios-textarea-affordance/textarea-empty-affordance.png`.

## Notes

- A device-specific `xcodebuild` attempt encountered slow CoreSimulator/system
  app startup and exceeded the 300-second harness timeout. The generic simulator
  `xcodebuild` command succeeded and produced the installed app.
- `agent-device` timed out while opening/attaching to the simulator in this
  session, so accessibility snapshots and tap/type automation were not captured.
  The code path still uses the same `TextEditor`, `StateManager` binding, and
  `.keyboardDoneToolbar()` as before; the targeted tests cover the new fallback
  placeholder/accessibility-label logic and the Jasonpedia fixture path.
