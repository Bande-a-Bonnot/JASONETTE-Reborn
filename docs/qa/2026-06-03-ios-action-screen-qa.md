# iOS Action-Screen QA — 2026-06-03

## Environment

- Date: 2026-06-03
- Initial git status: `main...origin/main`, clean working tree before QA artifacts/report creation
- Commit under test: `619ff16c31fa239c69f5a9ee5ef5113cdb9f3189`
- macOS: 26.2 (`25C56`)
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID `61EA0147-56E4-4399-8D51-F98A93B708A6`
- `agent-device`: 0.16.11
- Artifact directory: `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/`

To make the media/address-book demos deterministic enough to exercise, I seeded the
Simulator with a QA vCard, PNG, and MP4 via `xcrun simctl addmedia`.

## Build / install / launch

```bash
cd JASONETTE-iOS/JasonetteApp
mise exec -- tuist generate --no-open
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
swift build
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  JASONETTE-iOS/JasonetteApp/DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
npx --yes agent-device@latest prepare ios-runner --platform ios --timeout 240000
```

Direct-entry launches used:

```bash
ENTRY_URL='https://...fixture.json'
xcrun simctl launch --terminate-running-process booted com.bande-a-bonnot.jasonette \
  -JasonetteEntryURL "$ENTRY_URL"

npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session actionqa \
  --platform ios \
  --device 'iPhone 17 Pro'
```

I attached with `agent-device` without `--relaunch` after each override launch, per
`docs/qa/README.md`. Visual evidence was captured with `simctl io screenshot`.

## Coverage and results

### 1. `$util.addressbook` direct fixture

Fixture: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/addressbook.json`

Result: **FAIL**

- First launch showed the iOS Contacts permission prompt.
- After tapping `Continue`, iOS 26 showed the newer contacts-access chooser with
  `Select Contacts` / `Share All 7 Contacts`.
- After granting access, the app dropped out to the Simulator Home screen instead
  of rendering contacts/empty-state UI.
- Relaunching the direct fixture with contacts permission already granted crashed
  immediately.
- Crash log shows an uncaught `CNPropertyNotFetchedException` while formatting a
  `CNContact`.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/addressbook-after-permission.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/addressbook-relaunch-env.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/addressbook-crash.log`

### 2. Action index media rows

Fixture: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/index.json`

#### `$media.play`

Result: **PARTIAL PASS**

- Tapping `$media.play` presented the native media sheet / AVPlayer surface.
- On Simulator, the sheet showed a black player surface with an
  `UnsupportedContentIndicator` / slashed-play overlay rather than visible video
  playback.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-play-sheet.png`

#### `$media.picker + $util.share (photo)`

Result: **PASS**

- Native Photos picker presented.
- The picker showed the iOS private-access banner (`Jasonette` can only access
  the items you select).
- Selecting a visible local photo opened the native share sheet.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-picker-photo.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-picker-share-sheet.png`

#### `$media.camera + $util.share (photo)`

Result: **PASS with Simulator fallback**

- On Simulator, the camera row fell back to the photo library instead of a real
  camera capture UI.
- Selecting a visible local photo opened the native share sheet.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-camera-photo-share-sheet.png`

#### `$media.camera + $util.share (photo with editing)`

Result: **PASS with Simulator fallback**

- On Simulator, the camera row fell back to the photo library.
- After selecting a visible local photo, the edit/crop UI appeared.
- Tapping `Choose` opened the native share sheet.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-camera-editing-crop.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-camera-editing-share-sheet.png`

#### `$media.camera + $util.share (video)`

Result: **PASS with Simulator fallback**

- On Simulator, the camera row fell back to the Videos picker.
- The seeded 2-second MP4 appeared in the picker.
- Selecting it showed the `Choose Video` preview, and `Choose` opened the native
  share sheet with the trimmed MP4 item.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-camera-video-preview.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-camera-video-share-sheet.png`

Notes:
- My first attempts picked the top-left blank/cloud-backed asset and produced
  misleading `Media picker unavailable` / `Camera unavailable` alerts. Selecting
  a visible local asset worked for the picker/camera photo flows.
- Evidence for that rough edge:
  `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/media-picker-alert.png`

### 3. `$geo.get` direct fixture

Fixture: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/geo/index.json`

Result: **FAIL**

- The fixture loaded and rendered `Display` / `Map` buttons.
- Tapping `Display` showed the system location-permission prompt.
- After `Allow While Using App`, repeated `Display` and `Map` taps produced no
  visible coordinate text and no visible map, even after setting the Simulator
  location to `37.3318,-122.0312` and waiting several seconds.
- Resetting permissions and choosing `Don't Allow` returned to the same blank
  fixture; no user-visible error UI appeared.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/geo-initial.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/geo-after-display.png`

### 4. `$snapshot` + `$util.share`

Fixture: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/background/index.json`

Result: **PASS**

- The fixture loaded normally.
- Tapping the bottom-left image button triggered `$snapshot`.
- The native share sheet presented with the captured image item.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/background-initial.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/snapshot-share-sheet.png`

### 5. `$vision.scan` best-effort check

Fixture: `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/action/vision/index.json`

Result: **INCONCLUSIVE / likely regression**

- The fixture loaded and stayed on `Scanning...`.
- No recognized fallback alert appeared during launch or after waiting 5 seconds.
- I did **not** observe positive evidence for the intended user-visible fallback;
  this looked like a silent no-op from the fixture surface.

Evidence:
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/vision-initial.png`

## Severity-sorted findings

### High

#### 1. `$util.addressbook` crashes after Contacts access / on direct relaunch

- Fixture: `Jasonpedia/action/addressbook.json`
- Repro:
  1. Reset/install the Debug app.
  2. Launch the direct address-book fixture.
  3. Grant Contacts access.
  4. Observe return to Home screen.
  5. Relaunch the same direct fixture with permission already granted.
  6. Observe immediate crash.
- Expected: render contacts, empty state, or error-branch UI.
- Actual: exits/crashes before rendering.
- Evidence: `addressbook-after-permission.png`, `addressbook-relaunch-env.png`,
  `addressbook-crash.log`
- Follow-up: add a todo to request all contact properties needed by the
  formatter/payload builder before using `CNContactFormatter`.

### Medium

#### 2. `$geo.get` permission prompt works, but success path never rendered coords or map

- Fixture: `Jasonpedia/action/geo/index.json`
- Repro:
  1. Set a simulated location with `xcrun simctl location ... set 37.3318,-122.0312`.
  2. Launch the direct geo fixture.
  3. Tap `Display`, allow location.
  4. Tap `Display` and `Map` again.
- Expected: coord text for `Display`, map render for `Map`.
- Actual: fixture remained visually unchanged.
- Evidence: `geo-initial.png`, `geo-after-display.png`
- Follow-up: add a todo to verify the location callback/success-chain rendering
  path on Simulator and make the failure case user-visible when no `error`
  action is authored.

### Follow-up / best-effort

#### 3. `$vision.scan` fallback was not user-visible from the direct fixture surface

- Fixture: `Jasonpedia/action/vision/index.json`
- Repro: launch the direct fixture and wait.
- Expected: explicit unsupported/fallback feedback instead of silent failure.
- Actual: page remained on `Scanning...`; I did not observe a fallback alert.
- Evidence: `vision-initial.png`
- Follow-up: confirm whether the intended fallback should fire on `$load` for
  this fixture, or whether the unsupported path is currently gated behind a flow
  that never becomes visible on Simulator.

## Notable non-issues / confirmed working

- `$media.picker + $util.share (photo)` presents Photos UI and a share sheet.
- `$media.camera + $util.share` photo/video variants use a reasonable Simulator
  photo-library fallback.
- The editing variant can complete through crop UI into the share sheet when a
  visible local photo is selected.
- `$snapshot` can chain directly into `$util.share` from the background fixture.
- `$media.play` at least presents the native media sheet, even though playback
  was not visually confirmed on Simulator.

## Areas not fully tested

- Completing a share action (for example saving/exporting from the share sheet)
- Real camera hardware capture on device
- Successful end-to-end `$util.addressbook` rendering, blocked by crash
- Successful end-to-end `$geo.get` success rendering, not observed
- A stronger `$vision.scan` conclusion than best-effort fixture observation

## Verification commands

```bash
cd JASONETTE-iOS/JasonetteApp && mise exec -- tuist generate --no-open
cd JASONETTE-iOS/JasonetteApp && xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataQA \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  JASONETTE-iOS/JasonetteApp/DerivedDataQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app
npx --yes agent-device@latest prepare ios-runner --platform ios --timeout 240000
npm run lint:md
```

## Summary

- **Pass:** `$media.picker`, `$media.camera` photo/video/editing fallback flows,
  `$snapshot + $util.share`
- **Partial pass:** `$media.play` sheet presentation only
- **Fail:** `$util.addressbook`, `$geo.get`
- **Best-effort follow-up:** `$vision.scan`
