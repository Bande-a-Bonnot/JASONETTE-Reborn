---
title: "Tuist + SPM Multi-Platform Architecture for App Archiving"
category: architecture-patterns
tags: [swift, spm, tuist, ios, multi-platform, archiving, testflight]
module: JASONETTE-iOS
symptom: "SPM package builds and tests pass, but cannot generate .xcodeproj for Archive → TestFlight"
root_cause: "SPM alone cannot generate .xcodeproj; executable targets require SPM app plugin or platform-specific wrapper"
---

# Tuist + SPM Multi-Platform Architecture for App Archiving

## Problem

An iOS app built with SPM works perfectly:
- `swift build` succeeds in <1 second
- All 68+ tests pass
- SwiftUI components render correctly in previews

But it cannot be archived for TestFlight because:
- SPM only builds frameworks and libraries
- No `.xcodeproj` file exists
- Xcode Archive action requires a `.xcodeproj` with code signing, bundle ID, and asset catalogs
- SPM's app plugin (Swift 5.9+) exists but doesn't expose the @main entry point for linking

## Root Cause

SPM executable targets are tightly coupled to the build system. They cannot be referenced as external dependencies by other build systems (like Tuist). The app plugin hides the `@main` behind framework encapsulation, making it unavailable for external linking.

## Solution Architecture

**Key insight**: Decouple the `@main` entry point from SPM by hosting it in a **library target per platform**, then use **Tuist sourceless shell targets** to create the .xcodeproj, linking against these SPM libraries.

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────┐
│  Tuist Project.swift (Generated .xcodeproj)         │
│  └─ sourceless shell targets per platform           │
│     └─ links to external SPM products               │
└─────────────────────────────────────────────────────┘
              ↓ (external dependency)
┌─────────────────────────────────────────────────────┐
│  Package.swift (SPM)                                │
│  ├─ Core library: "Jasonette" (.library)            │
│  └─ Platform app libraries (.library)               │
│     ├─ "JasonetteApp-iOS" + App.swift (@main)       │
│     ├─ "JasonetteApp-macOS" + App.swift (@main)     │
│     ├─ "JasonetteApp-tvOS" + App.swift (@main)      │
│     └─ "JasonetteApp-visionOS" + App.swift (@main)  │
└─────────────────────────────────────────────────────┘
              ↓ (swift build, swift test)
┌─────────────────────────────────────────────────────┐
│  Local development via SPM                          │
│  (No Tuist needed for development/testing)          │
└─────────────────────────────────────────────────────┘
```

### Why This Works

1. **SPM handles core logic** (.library target) — shared, well-tested, fast feedback
2. **Platform libraries expose @main** — public struct with public init(), linkable by external build systems
3. **Tuist provides .xcodeproj** — code signing, bundle ID, asset catalogs, provisioning profiles
4. **Separation of concerns** — SPM for business logic, Tuist for platform deployment

## Step-by-Step Implementation

### Step 1: Create Platform-Specific Library Targets in Package.swift

Replace executable targets with library targets. Each contains a @main App struct.

**File**: `/JASONETTE-iOS/JasonetteApp/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JasonetteApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        // Core library — shared business logic
        .library(name: "Jasonette", targets: ["Jasonette"]),

        // Platform app libraries — contain @main entry points
        .library(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"]),
        .library(name: "JasonetteApp-macOS", targets: ["JasonetteApp-macOS"]),
        .library(name: "JasonetteApp-tvOS", targets: ["JasonetteApp-tvOS"]),
        .library(name: "JasonetteApp-visionOS", targets: ["JasonetteApp-visionOS"]),
    ],
    targets: [
        // Core library target
        .target(
            name: "Jasonette",
            path: "Sources/Jasonette"
        ),

        // Platform app library targets
        .target(
            name: "JasonetteApp-iOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-iOS"
        ),
        .target(
            name: "JasonetteApp-macOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-macOS"
        ),
        .target(
            name: "JasonetteApp-tvOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-tvOS"
        ),
        .target(
            name: "JasonetteApp-visionOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-visionOS"
        ),

        // Tests — depend on core library only
        .testTarget(
            name: "JasonetteTests",
            dependencies: ["Jasonette"],
            path: "Tests/JasonetteTests"
        ),
    ]
)
```

### Step 2: Create Platform App Library Files with @main

Each platform gets its own `App.swift` file in a dedicated source directory.

**File**: `/JASONETTE-iOS/JasonetteApp/Sources/JasonetteApp-iOS/App.swift`

```swift
import SwiftUI
import Jasonette

@main
public struct JasonetteApp: App {
    // CRITICAL: Must be public because this is in a library target
    public init() {}

    public var body: some Scene {
        WindowGroup {
            JasonetteNavigationView(
                url: URL(string: "https://example.com/demo.json")!
            )
        }
    }
}
```

**Same pattern for macOS, tvOS, visionOS** — identical App.swift files in their respective directories:
- `Sources/JasonetteApp-macOS/App.swift`
- `Sources/JasonetteApp-tvOS/App.swift`
- `Sources/JasonetteApp-visionOS/App.swift`

### Step 3: Create Tuist Package Bridge

Tuist needs to resolve the local SPM package. Create a package settings file.

**File**: `/JASONETTE-iOS/JasonetteApp/Tuist/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

// Tell Tuist to use default product types (no special handling)
let packageSettings = PackageSettings(productTypes: [:])
#endif

let package = Package(
    name: "JasonetteDependencies",
    dependencies: [
        // Reference the parent directory's Package.swift
        .package(path: "..")
    ]
)
```

### Step 4: Create Tuist Sourceless Shell Targets

Create shell targets that have no source code themselves, but link the SPM libraries for code signing and bundling.

**File**: `/JASONETTE-iOS/JasonetteApp/Project.swift`

```swift
import ProjectDescription

let project = Project(
    name: "Jasonette",
    settings: .settings(base: [
        "MARKETING_VERSION": "0.1.0",
        "CURRENT_PROJECT_VERSION": "1",
    ]),
    targets: [
        // MARK: - iOS App
        .target(
            name: "Jasonette-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.example.jasonette",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            // CRITICAL: sources: [] — @main comes from linked library
            sources: [],
            // Assets and resources — referenced by bundle ID
            resources: ["Resources/iOS/**"],
            // Link the SPM library containing @main
            dependencies: [.external(name: "JasonetteApp-iOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "YOUR_TEAM_ID"))
        ),

        // MARK: - macOS App
        .target(
            name: "Jasonette-macOS",
            destinations: [.mac],
            product: .app,
            bundleId: "com.example.jasonette.macos",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.external(name: "JasonetteApp-macOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "YOUR_TEAM_ID"))
        ),

        // MARK: - tvOS App
        .target(
            name: "Jasonette-tvOS",
            destinations: [.appleTv],
            product: .app,
            bundleId: "com.example.jasonette.tvos",
            deploymentTargets: .tvOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.external(name: "JasonetteApp-tvOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "YOUR_TEAM_ID"))
        ),

        // MARK: - visionOS App
        .target(
            name: "Jasonette-visionOS",
            destinations: [.appleVision],
            product: .app,
            bundleId: "com.example.jasonette.visionos",
            deploymentTargets: .visionOS("1.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.external(name: "JasonetteApp-visionOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "YOUR_TEAM_ID"))
        ),
    ]
)
```

## Critical Code Patterns

### Pattern 1: Public Access in Library Targets

The `JasonetteApp` struct **must be public** because it's in a library target:

```swift
// ✅ CORRECT — public struct + public init
@main
public struct JasonetteApp: App {
    public init() {}  // Must be public
    public var body: some Scene { ... }
}

// ❌ WRONG — internal (default) is not accessible to external code
@main
struct JasonetteApp: App {  // internal by default
    init() {}  // internal — cannot be instantiated from linked library
    var body: some Scene { ... }
}
```

### Pattern 2: Library vs. Executable Products

```swift
// ✅ CORRECT — library products for Tuist linking
products: [
    .library(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"]),
]

// ❌ WRONG — executable products cannot be linked by external build systems
products: [
    .executable(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"]),
]
```

### Pattern 3: Sourceless Tuist Targets

```swift
// ✅ CORRECT — sources: [] with external dependency link
.target(
    name: "Jasonette-iOS",
    product: .app,
    sources: [],  // No source code
    dependencies: [.external(name: "JasonetteApp-iOS")],  // Link SPM library
)

// ❌ WRONG — sources: [] without dependency produces linking error
.target(
    name: "Jasonette-iOS",
    product: .app,
    sources: [],
    dependencies: []  // Missing link to @main
)
```

## Key Gotchas and Solutions

### Gotcha 1: "Unknown symbol" Linking Error

**Symptom**: `ld: symbol not found for architecture arm64: _main`

**Cause**: Sources are empty but no external dependency is linked.

**Solution**: Ensure `dependencies: [.external(name: "JasonetteApp-iOS")]` is present and the library name matches Package.swift exactly.

### Gotcha 2: "Cannot find 'JasonetteApp' in scope"

**Symptom**: Tuist generates .xcodeproj but linker fails.

**Cause**: The App struct in the library is internal (default access level).

**Solution**: Mark as `public struct JasonetteApp`.

### Gotcha 3: @main Attribute on Library Member

**Symptom**: "Program does not contain definition of `main`"

**Cause**: Library targets don't automatically expose @main. Swift requires the entry point to be discoverable.

**Solution**: Use Tuist's sourceless target pattern — the SPM library provides @main, Tuist creates the executable wrapper.

### Gotcha 4: Asset Catalog Not Found

**Symptom**: App runs but assets (icons, images) are missing.

**Cause**: Resources path incorrect or not specified in Tuist target.

**Solution**:
```swift
resources: ["Resources/iOS/**"],  // Glob pattern
infoPlist: .extendingDefault(with: [...])  // Bundle ID registration
```

### Gotcha 5: Multiple @main Symbols

**Symptom**: Linker error when both SPM library and Tuist target have @main.

**Cause**: Each platform library contains a @main struct, but Tuist also tries to provide one.

**Solution**: **Always use sourceless targets** (`sources: []`). Let the linked SPM library provide @main.

## Verification Commands

### Verify SPM Works Standalone

```bash
cd JASONETTE-iOS/JasonetteApp
swift build              # Should succeed in <1s
swift test               # Should pass all tests
```

**Expected output**:
```
Building for debugging...
Build complete! (0.14s)

Test Suite 'JasonetteAppPackageTests.xctest' passed
Executed 68 tests, with 0 failures in 0.049 seconds
```

### Generate Tuist Project

```bash
cd JASONETTE-iOS/JasonetteApp
tuist generate           # Generate .xcodeproj from Project.swift
```

**Expected output**:
```
Generating Jasonette.xcodeproj...
Project generated at JASONETTE-iOS/JasonetteApp/Jasonette.xcodeproj
```

### Verify .xcodeproj Structure

```bash
# Check that shell target has no sources
xcodebuild -project JASONETTE-iOS/JasonetteApp/Jasonette.xcodeproj \
    -target Jasonette-iOS \
    -showBuildSettings | grep SRCROOT

# Check that external dependency is linked
xcodebuild -project JASONETTE-iOS/JasonetteApp/Jasonette.xcodeproj \
    -target Jasonette-iOS \
    -showBuildSettings | grep -i "jasonette\|depend"
```

### Build via Xcode

```bash
cd JASONETTE-iOS/JasonetteApp
xcodebuild -project Jasonette.xcodeproj \
    -target Jasonette-iOS \
    -configuration Debug \
    -sdk iphonesimulator \
    build
```

**Expected output**:
```
Build complete! (1.23s)
```

### Archive for TestFlight

```bash
xcodebuild -project Jasonette.xcodeproj \
    -target Jasonette-iOS \
    -scheme Jasonette-iOS \
    -configuration Release \
    -sdk iphoneos \
    archive \
    -archivePath /tmp/Jasonette.xcarchive
```

**Expected output**:
```
Archive complete!
Created archive at /tmp/Jasonette.xcarchive
```

## File Structure

```
JASONETTE-iOS/JasonetteApp/
├── Package.swift                          # SPM manifest (5 products, 5 targets)
├── Project.swift                          # Tuist manifest (4 shell app targets)
├── Tuist/
│   └── Package.swift                      # Tuist package bridge
├── Sources/
│   ├── Jasonette/                         # Core library (shared logic)
│   │   ├── Core/
│   │   ├── Template/
│   │   ├── Components/
│   │   └── ...
│   ├── JasonetteApp-iOS/
│   │   └── App.swift                      # @main entry point for iOS
│   ├── JasonetteApp-macOS/
│   │   └── App.swift                      # @main entry point for macOS
│   ├── JasonetteApp-tvOS/
│   │   └── App.swift                      # @main entry point for tvOS
│   └── JasonetteApp-visionOS/
│       └── App.swift                      # @main entry point for visionOS
├── Resources/
│   └── iOS/
│       └── Assets.xcassets/               # Referenced by Tuist shell target
├── Tests/
│   └── JasonetteTests/                    # Tests for core library
└── Jasonette.xcodeproj/                   # Generated by Tuist (git-ignored)
    ├── Jasonette-iOS/
    ├── Jasonette-macOS/
    ├── Jasonette-tvOS/
    └── Jasonette-visionOS/
```

## Git Configuration

Add to `.gitignore`:

```gitignore
# Tuist generated artifacts
Derived/
.tuist/
Tuist/.build/
*.xcworkspace/
Jasonette.xcodeproj/
```

## Summary

This architecture enables:
- ✅ **Fast SPM development** — `swift build` in <1s, `swift test` passes 68 tests
- ✅ **Multi-platform support** — iOS, macOS, tvOS, visionOS from single codebase
- ✅ **App archiving** — generates .xcodeproj with proper code signing, bundle ID, assets
- ✅ **TestFlight distribution** — Archive → Export → Upload to TestFlight
- ✅ **Clear separation** — Business logic in SPM, platform deployment in Tuist
- ✅ **No duplication** — Core library shared across all platforms

The key insight is that `@main` doesn't need to be an executable target — it can be a public struct in a library, discoverable by linkers when explicitly linked. This decouples the entry point from the build system, allowing SPM for development and Tuist for distribution.
