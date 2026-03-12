---
title: "Xcode Cloud ITMS-90035: Tuist project signs with development certificate instead of distribution"
date: 2026-03-11
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

Tuist's `.automaticCodeSigning(devTeam:)` hardcodes `CODE_SIGN_IDENTITY = "iPhone Developer"` into the generated `.xcodeproj` base settings. Xcode Cloud reads this and uses a development certificate for archives instead of letting its cloud-managed signing pick the right certificate per build action.

## What Doesn't Work

### automaticCodeSigning alone

```swift
// BROKEN: hardcodes CODE_SIGN_IDENTITY = "iPhone Developer"
settings: .settings(base: SettingsDictionary()
    .automaticCodeSigning(devTeam: "PKPPLFK854"))
```

### Adding release CODE_SIGN_IDENTITY override

```swift
// BROKEN on Xcode Cloud: cloud-managed signing ignores this override
settings: .settings(
    base: SettingsDictionary()
        .automaticCodeSigning(devTeam: "PKPPLFK854"),
    release: ["CODE_SIGN_IDENTITY": "Apple Distribution"]
)
```

This works for local archives but Xcode Cloud manages its own certificates and does not honor explicit `CODE_SIGN_IDENTITY` overrides in the project.

### Manual CODE_SIGN_STYLE + DEVELOPMENT_TEAM without excluding defaults

```swift
// BROKEN: Tuist's recommended defaults still inject CODE_SIGN_IDENTITY
settings: .settings(base: [
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "PKPPLFK854",
])
```

## What Works

Exclude `CODE_SIGN_IDENTITY` from Tuist's recommended defaults so it never appears in the generated project. Xcode Cloud then picks the right identity automatically per build action:

```swift
let automaticSigningSettings: Settings = .settings(
    base: [
        "CODE_SIGN_STYLE": "Automatic",
        "DEVELOPMENT_TEAM": "PKPPLFK854",
    ],
    defaultSettings: .recommended(excluding: ["CODE_SIGN_IDENTITY"])
)
```

Then reference it from each target:

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
    settings: automaticSigningSettings
)
```

## Why This Works

- `CODE_SIGN_STYLE: "Automatic"` tells Xcode to manage signing
- `DEVELOPMENT_TEAM` identifies the team
- `excluding: ["CODE_SIGN_IDENTITY"]` prevents Tuist from injecting any identity
- Xcode Cloud's cloud-managed signing selects development cert for builds, distribution cert for archives

## Prevention

- Never use `.automaticCodeSigning(devTeam:)` for Xcode Cloud projects — it hardcodes `"iPhone Developer"`
- Always use `defaultSettings: .recommended(excluding: ["CODE_SIGN_IDENTITY"])` with manual signing settings
- Verify: `xcodebuild -showBuildSettings | grep CODE_SIGN_IDENTITY` should show nothing or `-` (automatic)

## Related

- `docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md`
- `docs/solutions/build-errors/xcode-cloud-ci-post-clone-working-directory.md`
- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
