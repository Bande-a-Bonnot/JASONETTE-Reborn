---
title: "Tuist .extendingDefault generates hardcoded CFBundleVersion instead of build setting variables"
date: 2026-03-21
category: build-errors
module: JasonetteApp
problem_type: build_error
component: tooling
symptoms:
  - "Every Xcode Cloud archive exports with build number 1 regardless of CI build number"
  - "App Store Connect rejects duplicate build numbers on subsequent uploads"
  - "Tuist-generated Info.plist has CFBundleVersion=1 and CFBundleShortVersionString=1.0 instead of $(CURRENT_PROJECT_VERSION)"
root_cause: config_error
resolution_type: config_change
severity: high
tags: [tuist, xcode-cloud, versioning, info-plist, build-number, testflight]
---

# Tuist .extendingDefault Generates Hardcoded Version Numbers

## Problem

Tuist's `.extendingDefault(with:)` generates Info.plist files with hardcoded `CFBundleVersion=1` and `CFBundleShortVersionString=1.0` instead of using build setting variables. This prevents Xcode Cloud from managing build numbers.

## Symptoms

- Every Xcode Cloud build archives with build number "1"
- App Store Connect rejects the upload as a duplicate build number
- `MARKETING_VERSION` build setting exists but Info.plist doesn't reference it
- `manageAppVersionAndBuildNumber` in export options can't override hardcoded plist values

## What Didn't Work

Setting `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Project.swift` settings was necessary but insufficient — Tuist's `.extendingDefault` still generated static values in the plist instead of variable references.

## Solution

Explicitly include the version variables in every target's `infoPlist` dictionary:

```swift
// Project.swift — all 4 platform targets
infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Jasonette",
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",      // was hardcoded "1.0"
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",           // was hardcoded "1"
    "ITSAppUsesNonExemptEncryption": false,
]),
```

After `tuist generate`, the derived Info.plist correctly references build settings:
```xml
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key>
<string>$(CURRENT_PROJECT_VERSION)</string>
```

## Why This Works

Tuist's `.extendingDefault` merges user-provided keys with its own defaults. Its defaults for `CFBundleVersion` and `CFBundleShortVersionString` are static strings (`"1"` and `"1.0"`). By explicitly providing these keys with variable references, the user values override Tuist's defaults, allowing Xcode and Xcode Cloud to resolve the variables at build time.

## Prevention

- When using Tuist `.extendingDefault`, always explicitly set `CFBundleShortVersionString` and `CFBundleVersion` to build setting variables
- Verify generated plists with `grep CFBundleVersion Derived/InfoPlists/*.plist` after `tuist generate`
- Apply to ALL platform targets, not just iOS

## Related Issues

- See also: [xcode-cloud-accent-character-team-name-crash.md](../integration-issues/xcode-cloud-accent-character-team-name-crash.md) — discovered during the same debugging session
- See also: [tuist-spm-multiplatform-testflight.md](../architecture-patterns/tuist-spm-multiplatform-testflight.md) — Tuist project architecture
