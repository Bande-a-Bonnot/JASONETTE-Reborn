# iOS Device-Specific Simulator Build QA — 2026-05-28

## Scope

Investigation for `todos/044`: the previous direct device-specific
`xcodebuild` to an iPhone 17 Pro simulator had hung during asset catalog
processing, while a generic simulator build only succeeded after clearing app
icon and accent-color asset compiler settings.

## Environment

- Date/time: 2026-05-28 UTC
- Commit under test: `e9fae7c` plus this todo's documentation/asset changes
- macOS: 26.2
- Xcode: 26.2 (`17C52`)
- Simulator: iPhone 17 Pro, iOS 26.2, UDID
  `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Tuist: `4.153.1` via `mise exec -- tuist version`

## Findings

The original hang was not reproducible in this environment on 2026-05-28. A
clean device-specific build for the booted iPhone 17 Pro completed successfully,
including the asset catalog phase.

Two project hygiene issues were identified while investigating:

1. `Jasonette.xcodeproj` is ignored/generated locally, so it can become stale
   relative to `Project.swift`. Run `mise exec -- tuist generate --no-open`
   before local `xcodebuild` QA.
2. The generated project references `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`,
   but the asset catalog previously had no `AccentColor.colorset`. The build
   still succeeded, but emitted an asset-catalog warning. Added the missing
   `AccentColor` colorset so the setting is valid.

## Commands Run

Generated the local Xcode project from the current Tuist manifest:

```bash
cd JASONETTE-iOS/JasonetteApp
mise exec -- tuist generate --no-open
```

Verified the generated deployment targets reflected current `Project.swift`:

```bash
rg -n 'IPHONEOS_DEPLOYMENT_TARGET|MACOSX_DEPLOYMENT_TARGET|TVOS_DEPLOYMENT_TARGET|XROS_DEPLOYMENT_TARGET' \
  Jasonette.xcodeproj/project.pbxproj
```

Result included:

```text
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
MACOSX_DEPLOYMENT_TARGET = 14.0;
TVOS_DEPLOYMENT_TARGET = 17.0;
XROS_DEPLOYMENT_TARGET = 1.0;
```

Device-specific simulator build:

```bash
rm -rf DerivedDataDeviceQA044
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=61EA0147-56E4-4399-8D51-F98A93B708A6' \
  -derivedDataPath DerivedDataDeviceQA044 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
CompileAssetCatalogVariant thinned ... Resources/iOS/Assets.xcassets
** BUILD SUCCEEDED **
```

No `Accent color 'AccentColor' is not present in any asset catalogs` warning was
emitted after adding `AccentColor.colorset`.

Generic simulator build without clearing asset-catalog settings:

```bash
rm -rf DerivedDataGenericQA044
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataGenericQA044 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
** BUILD SUCCEEDED **
```

Install/launch of the device-specific build:

```bash
xcrun simctl install 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  DerivedDataDeviceQA044/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette
```

Result: app launched successfully (`com.bande-a-bonnot.jasonette: 16967`).

## Outcome

`todos/044` is resolved as a local dev-infra/documentation issue:

- Device-specific simulator build now succeeds on the affected simulator.
- The asset-catalog setting is valid because `AccentColor.colorset` exists.
- The documented build path now starts with `tuist generate` and no longer needs
  the old app-icon/accent-color clearing workaround.

## Remaining Notes

This pass does not prove the May 18 hang was impossible; it only shows it is not
reproducible with the current toolchain/project state. If the hang returns, keep
using a clean `-derivedDataPath`, confirm the local generated Xcode project is
fresh, and preserve the full `xcodebuild` log before deleting DerivedData.
