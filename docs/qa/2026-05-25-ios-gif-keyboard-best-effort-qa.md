# iOS GIF + Keyboard Dismissal Best-Effort QA

Date: 2026-05-25

## Scope

- `todos/046` — animated GIF image rendering
- `todos/047` — keyboard dismissal behavior for text inputs

## What Changed

- GIF image URLs now route to a UIKit-backed `UIImageView` renderer on iOS.
- Static image URLs continue to use the existing SwiftUI `AsyncImage` path.
- Text fields, secure fields, text areas, and footer input text fields now expose a Done/submit dismissal path.
- Scrolling content uses interactive keyboard dismissal, and the rendered document surface sends a responder-chain keyboard dismiss on outside taps.

## Evidence Collected

Commands run:

```bash
cd JASONETTE-iOS/JasonetteApp && swift test
cd JASONETTE-iOS/JasonetteApp && xcodebuild -scheme Jasonette-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/Jasonette-gjsgodxgibvmjpbukwqfaewstcsf/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
xcrun simctl launch booted com.bande-a-bonnot.jasonette
xcrun simctl io booted screenshot \
  docs/qa/artifacts/2026-05-25-ios-gif-keyboard/default-launch.png
```

Results:

- Swift tests: 483 tests, 0 failures.
- iOS simulator build: succeeded for `iPhone 17 Pro` on iOS 26.2, deployment target iOS 16.0.
- App installed and launched on the booted simulator.
- Default launch screenshot captured at
  `docs/qa/artifacts/2026-05-25-ios-gif-keyboard/default-launch.png`.

## Limitations

Direct visual QA for a specific GIF fixture and textfield fixture was not completed in this session. The app currently launches the hosted Jasonpedia demo URL, and the direct debug launch URL override is still tracked separately in `todos/043`. A still screenshot also cannot prove GIF animation by itself.

An attempt to use `agent-device snapshot -i` against the running simulator timed out after 60 seconds, so no reliable interactive element tree was captured for fixture navigation.

## Conclusion

This is a best-effort simulator QA pass: the iOS-specific code paths compile in an iOS Simulator build and the app launches successfully. Unit tests cover GIF URL detection/path selection and relative GIF URL resolution. Follow-up direct fixture visual QA remains easiest after `todos/043` adds a debug launch URL override.
