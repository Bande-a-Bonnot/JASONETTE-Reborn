---
module: JasonetteApp
date: 2026-03-21
problem_type: integration_issue
component: tooling
symptoms:
  - "CoreDeviceService crash (EXC_BAD_INSTRUCTION) during Xcode Cloud archive task"
  - "teamName='(null)' in all distribution logs"
  - "Unable to authenticate with App Store Connect (Error Code=1)"
root_cause: config_error
resolution_type: config_change
severity: critical
tags: [xcode-cloud, code-signing, unicode, apple-developer-account, tuist, coredeviceservice]
---

# Xcode Cloud Systematic Crash: Accent Character in Apple Developer Account Name

## Problem

Xcode Cloud archive task systematically crashed during the distribution/export phase. The build and archive succeeded, but CoreDeviceService (Apple's internal device management XPC service) hit a Swift assertion failure every time, preventing TestFlight upload.

## Environment
- Module: JasonetteApp (Tuist + SPM)
- Xcode Cloud macOS VM: MacVM1,1 running macOS 26.3 (25D125)
- Xcode: 17C529 (toolchain)
- Team ID: PKPPLFK854
- Date: 2026-03-21

## Symptoms
- `CoreDeviceService` crash: `EXC_BAD_INSTRUCTION (SIGILL)` in `_assertionFailure` -> `swift_errorInMain`
- `teamName='(null)'` in every `IDEDistributionContext` in distribution logs
- `IDEDistribution.critical.log`: "Unable to authenticate with App Store Connect (Error Domain=DVTITunesSoftwareServiceFoundation Code=1)"
- `IDEDistribution.standard.log`: "Failed to find an account with App Store Connect access for team"
- Archive succeeded (`** ARCHIVE SUCCEEDED **`)
- IPA exported successfully (valid `.ipa` file produced)
- Crash happened systematically on every build, not intermittently

## What Didn't Work

**Attempted Solution 1:** Analyzed crash log assuming it was an app code issue
- **Why it failed:** The crash was in Apple's `CoreDeviceService` (image index 0), not in Jasonette code. Stack trace: `CoreDeviceService main()` -> `swift_errorInMain` -> `_assertionFailure`. No Jasonette frames.

**Attempted Solution 2:** Diagnosed as missing App Store Connect API credentials
- **Why it failed:** Xcode Cloud handles ASC authentication natively — no credentials need to be configured. The auth error was a symptom, not the cause.

**Attempted Solution 3:** Diagnosed as duplicate build number (CFBundleVersion hardcoded to "1")
- **Why it failed:** While the hardcoded version was a real secondary issue (Tuist generated static values instead of `$(CURRENT_PROJECT_VERSION)`), fixing it didn't resolve the CoreDeviceService crash. The crash happened before the build number mattered.

## Solution

The Apple Developer account name contained an accent character (non-ASCII). This broke Xcode Cloud's certificate and identity resolution chain, causing `teamName` to resolve to `(null)` throughout the distribution pipeline.

**Steps taken to fix:**

1. Contacted Apple Developer Support to rename the account (removing the accent character)
2. Deleted Xcode Cloud managed signing certificates (they were issued against the broken name)
3. Xcode Cloud re-provisioned with the clean account name on next build

**Secondary fix** (code change — nice to have):

```swift
// Project.swift - Before:
settings: .settings(base: [
    "MARKETING_VERSION": "0.1.0",
    "CURRENT_PROJECT_VERSION": "1",
]),
// Info.plist had hardcoded CFBundleVersion=1, CFBundleShortVersionString=1.0

// After:
settings: .settings(base: [
    "MARKETING_VERSION": "2.0.0",
    "CURRENT_PROJECT_VERSION": "1",
]),
// All targets now include:
"CFBundleShortVersionString": "$(MARKETING_VERSION)",
"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
```

## Why This Works

Xcode Cloud's distribution pipeline resolves the team identity from the Apple Developer account name when creating/managing signing certificates and provisioning profiles. When the account name contains non-ASCII characters (accents, special characters), the identity resolution fails silently — `teamName` becomes `(null)` — and downstream operations (ASC authentication, certificate matching) fail because they can't match the team.

The `CoreDeviceService` crash is Apple's XPC service hitting a Swift precondition failure when it encounters the `nil` team name in a code path that expects it to be non-nil.

Deleting the managed certificates after the rename is necessary because the old certificates were issued with the accented name and won't match the new clean name.

## Prevention

- Avoid non-ASCII characters (accents, umlauts, emoji) in Apple Developer account names
- If Xcode Cloud distribution fails with `teamName='(null)'`, check the account name in App Store Connect for special characters
- Always use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` in Tuist-generated Info.plists — never hardcode version strings
- When using Tuist `.extendingDefault`, explicitly set `CFBundleShortVersionString` and `CFBundleVersion` to build setting variables

## Related Issues

- See also: [xcode-cloud-itms90035-distribution-signing.md](../build-errors/xcode-cloud-itms90035-distribution-signing.md) — another Xcode Cloud signing issue (wrong certificate type)
- See also: [tuist-spm-multiplatform-testflight.md](../architecture-patterns/tuist-spm-multiplatform-testflight.md) — Tuist + SPM architecture for Xcode Cloud
