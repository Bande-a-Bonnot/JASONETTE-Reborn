---
title: "Xcode Cloud ITMS-90035: Tuist project signs with development certificate instead of distribution"
date: 2026-03-08
category: build-errors
tags: [xcode-cloud, code-signing, tuist, testflight, itms-90035, distribution-certificate]
module: JasonetteApp
symptom: "ITMS-90035: Invalid Signature - Code failed to satisfy specified code requirement(s)"
---

# Xcode Cloud ITMS-90035: Wrong Code Signing Identity

## Problem

Xcode Cloud archive + TestFlight upload fails with:

```
ITMS-90035: Invalid Signature - Code failed to satisfy specified code
requirement(s). The file at path "Jasonette_iOS.app/Jasonette_iOS" is
not properly signed. Make sure you have signed your application with a
distribution certificate, not an ad hoc certificate or a development
certificate.
```

## Root Cause

Tuist's `.automaticCodeSigning(devTeam:)` sets `CODE_SIGN_STYLE = Automatic` and `DEVELOPMENT_TEAM`, but does NOT set `CODE_SIGN_IDENTITY` for Release builds. Without an explicit identity, the archive may use a development certificate instead of the distribution certificate required for TestFlight/App Store.

## What Doesn't Work

### automaticCodeSigning alone

```swift
// Project.swift — SIGNS WITH DEVELOPMENT CERT
settings: .settings(base: SettingsDictionary()
    .automaticCodeSigning(devTeam: "PKPPLFK854"))
```

This sets:
- `CODE_SIGN_STYLE` = `Automatic`
- `DEVELOPMENT_TEAM` = `PKPPLFK854`

But `CODE_SIGN_IDENTITY` defaults to development, so archives get signed with "Apple Development" instead of "Apple Distribution."

## What Works

Add `CODE_SIGN_IDENTITY: "Apple Distribution"` to the Release configuration:

```swift
// Project.swift — CORRECT
settings: .settings(
    base: SettingsDictionary()
        .automaticCodeSigning(devTeam: "PKPPLFK854"),
    release: ["CODE_SIGN_IDENTITY": "Apple Distribution"]
)
```

This keeps Debug builds using the development certificate (for simulator/device testing) while Release builds (used by Xcode Cloud Archive) use the distribution certificate.

## Apple's Signing Identity Values

| Identity | Use case |
|----------|----------|
| `Apple Development` | Local builds, simulator, device testing |
| `Apple Distribution` | App Store, TestFlight, archive |
| `Developer ID Application` | Direct distribution outside App Store (macOS) |
| `iPhone Distribution` | Legacy (pre-Xcode 11), equivalent to Apple Distribution for iOS |

## Full Tuist Target Example

```swift
.target(
    name: "Jasonette-iOS",
    destinations: [.iPhone, .iPad],
    product: .app,
    bundleId: "com.bande-a-bonnot.jasonette",
    deploymentTargets: .iOS("16.0"),
    infoPlist: .extendingDefault(with: [
        "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
        "CFBundleDisplayName": "Jasonette",
        "ITSAppUsesNonExemptEncryption": false,
    ]),
    sources: [],
    resources: ["Resources/iOS/**"],
    dependencies: [.package(product: "JasonetteApp-iOS")],
    settings: .settings(
        base: SettingsDictionary()
            .automaticCodeSigning(devTeam: "YOUR_TEAM_ID"),
        release: ["CODE_SIGN_IDENTITY": "Apple Distribution"]
    )
)
```

## Prevention

- Always set Release `CODE_SIGN_IDENTITY` when configuring Tuist targets for App Store / TestFlight distribution
- The `automaticCodeSigning(devTeam:)` helper is necessary but not sufficient for distribution
- Test locally: `xcodebuild -showBuildSettings -configuration Release | grep CODE_SIGN_IDENTITY` should show "Apple Distribution"

## Related

- `docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md`
- `docs/solutions/build-errors/xcode-cloud-ci-post-clone-working-directory.md`
- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
