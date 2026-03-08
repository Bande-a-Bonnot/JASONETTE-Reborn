---
title: "SPM libraries with @main enable sourceless Tuist shell targets for multi-platform distribution"
date: 2026-03-02
category: architecture-patterns
tags: [tuist, spm, swift-package-manager, multi-platform, testflight, ios, macos, tvos, visionos]
module: JasonetteApp
symptom: "SPM package builds and tests pass but cannot Archive → TestFlight without .xcodeproj"
severity: design-pattern
resolution_time: "4 atomic commits"
related:
  - docs/solutions/swift-caseless-enum-no-init.md
  - docs/solutions/swift-recursive-codable-structs.md
  - docs/solutions/build-errors/xcode-cloud-ci-post-clone-working-directory.md
  - docs/solutions/build-errors/xcode-cloud-itms90035-distribution-signing.md
  - docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md
---

# Tuist + SPM Multi-Platform Architecture for TestFlight

## Problem

An iOS app built with SPM works perfectly (`swift build` <1s, 68 tests pass, 9 SwiftUI components render) but has no `.xcodeproj`, so it cannot Archive → TestFlight.

SPM alone cannot generate `.xcodeproj`. Xcode Archive requires code signing, bundle IDs, and asset catalogs — all `.xcodeproj` concerns.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Tuist Project.swift (generates .xcodeproj)          │
│  └─ sourceless shell targets per platform            │
│     └─ links external SPM products                   │
└──────────────────────┬──────────────────────────────┘
                       ↓ .external(name:)
┌─────────────────────────────────────────────────────┐
│  Package.swift (SPM)                                 │
│  ├─ Core library: "Jasonette" (.library)             │
│  └─ Platform app libraries (.library, not executable)│
│     ├─ "JasonetteApp-iOS"     → App.swift (@main)    │
│     ├─ "JasonetteApp-macOS"   → App.swift (@main)    │
│     ├─ "JasonetteApp-tvOS"    → App.swift (@main)    │
│     └─ "JasonetteApp-visionOS"→ App.swift (@main)    │
└──────────────────────┬──────────────────────────────┘
                       ↓ swift build / swift test
┌─────────────────────────────────────────────────────┐
│  Local development via SPM (no Tuist needed)         │
└─────────────────────────────────────────────────────┘
```

## Key Insight: Library vs Executable

SPM executables are standalone CLI binaries — they **cannot** be linked into Xcode app targets. The linker expects `@main` inside the Xcode target itself.

**Solution:** Declare platform app targets as `.library` products. Libraries can be linked into Xcode targets, and the linker discovers the `@main` entry point from the linked library.

```swift
// ✅ Library — linkable by Tuist shell targets
.library(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"])

// ❌ Executable — cannot be linked by external build systems
.executable(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"])
```

## Critical Patterns

### 1. Public access in library targets

The `@main` struct **must** be `public` with `public init()` since it's in a library:

```swift
// ✅ Correct
@main
public struct JasonetteApp: App {
    public init() {}
    public var body: some Scene { ... }
}

// ❌ Internal (default) — not accessible from linked target
@main
struct JasonetteApp: App { ... }
```

### 2. Sourceless Tuist targets with local package

Tuist targets have zero source files. All code lives in SPM. Use `packages:` at project level with `.local(path: ".")` and `.package(product:)` in target dependencies:

```swift
let project = Project(
    name: "Jasonette",
    packages: [.local(path: ".")],  // local SPM package at project root
    targets: [
        .target(
            name: "Jasonette-iOS",
            product: .app,
            sources: [],  // no sources — @main comes from linked SPM library
            dependencies: [.package(product: "JasonetteApp-iOS")],
        ),
    ]
)
```

**Do NOT use `Tuist/Package.swift` with `.package(path: "..")`** — Tuist 4 auto-discovers the root `Package.swift` and the bridge creates a "Duplicate values for key" crash when both resolve to the same directory path.

## Common Gotchas

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ld: symbol not found: _main` | Missing SPM link in Tuist target | Add `.package(product: "JasonetteApp-iOS")` to dependencies |
| "Cannot find 'JasonetteApp' in scope" | App struct is internal (default) | Mark as `public struct` with `public init()` |
| "Duplicate values for key" crash | `Tuist/Package.swift` path collides with project root | Remove `Tuist/Package.swift`, use `packages: [.local(path: ".")]` instead |
| "`X` is not a valid configured external dependency" | Using `.external(name:)` for local package products | Use `.package(product:)` instead of `.external(name:)` |
| `packages:` must precede `settings:` | Swift argument order in `Project()` init | Move `packages:` parameter before `settings:` |
| Assets missing at runtime | Resources path not in Tuist target | Add `resources: ["Resources/iOS/**"]` |
| `swift test` fails after refactor | Tests importing removed executable | Tests should only depend on core `Jasonette` lib |

## Platform Matrix

| Platform | SPM Library | Tuist Target | Deployment | Bundle ID Suffix |
|----------|-------------|--------------|------------|------------------|
| iOS | `JasonetteApp-iOS` | `Jasonette-iOS` | 16.0 | (none) |
| macOS | `JasonetteApp-macOS` | `Jasonette-macOS` | 13.0 | `.macos` |
| tvOS | `JasonetteApp-tvOS` | `Jasonette-tvOS` | 16.0 | `.tvos` |
| visionOS | `JasonetteApp-visionOS` | `Jasonette-visionOS` | 1.0 | `.visionos` |

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Libraries not executables | Libraries can be linked into Xcode targets; executables cannot |
| Sourceless Tuist targets | Clean separation: Tuist = config, SPM = code |
| Single 1024x1024 icon | Modern Xcode auto-generates all sizes |
| `ITSAppUsesNonExemptEncryption: false` | Skips export compliance prompt per TestFlight upload |
| `TEAM_ID_HERE` placeholder | Each developer inserts their own Team ID |

## Verification

```bash
swift build    # <1s cached, ~0.7s clean
swift test     # 68 tests, 0 failures
tuist install  # resolve local SPM package
tuist generate # produce .xcodeproj → open in Xcode
```

## Implementation Commits

| Commit | Change |
|--------|--------|
| `10e86e0` | Replace executable with 4 platform library targets |
| `6e3aff8` | Add Tuist manifests (Project.swift, Tuist.swift, Tuist/Package.swift) |
| `f5cbb93` | Add iOS app icon from legacy assets |
| `e027c08` | Add Tuist-related entries to .gitignore |
