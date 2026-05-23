---
status: ready
priority: p3
issue_id: "044"
tags: [ios, build, simulator, xcode, qa]
dependencies: []
---

# Investigate device-specific simulator build hang during asset catalog processing

## Problem Statement

During simulator QA, a direct device-specific `xcodebuild` for the iPhone 17 Pro
simulator hung during asset catalog processing and timed out after 10 minutes. A
generic simulator build succeeded when app icon/accent asset compiler settings
were cleared on the command line.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- QA doc: `docs/qa/2026-05-23-ios-html-component-qa.md`
- Failed/hung command:

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

- Workaround command used for QA:

```bash
xcodebuild \
  -project Jasonette.xcodeproj \
  -scheme Jasonette-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedDataQA2 \
  CODE_SIGNING_ALLOWED=NO \
  ASSETCATALOG_COMPILER_APPICON_NAME= \
  ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= \
  build
```

## Recommended Action

1. Reproduce in a clean terminal and in Xcode GUI.
2. Check whether Tuist-generated asset catalog settings are valid for Xcode 26.2
   / iOS 26.2 simulator runtimes.
3. Determine whether this is local-toolchain flakiness or a project setting
   problem.
4. If project-related, fix the asset catalog settings or document the simulator
   build command.

## Acceptance Criteria

- [ ] Device-specific simulator build either succeeds reliably or has a
      documented known-good workaround
- [ ] If a project setting is at fault, it is fixed
- [ ] QA docs reflect the recommended build/install path

## Notes

This is currently a QA/dev-infra issue, not known to affect CI or TestFlight.
The generic simulator build workaround succeeded again during the 2026-05-23
HTML component QA pass.
