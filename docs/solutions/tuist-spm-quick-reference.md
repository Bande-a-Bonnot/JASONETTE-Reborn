---
title: "Tuist + SPM Quick Reference"
category: quick-reference
tags: [swift, spm, tuist, checklist]
---

# Tuist + SPM Quick Reference

## The Core Idea in 30 Seconds

- **Package.swift**: Declare core library (`Jasonette`) + platform libraries (`JasonetteApp-iOS`, etc.) as `.library` products with @main structs
- **App.swift**: Each platform has identical `public struct JasonetteApp` with `public init()` (must be public for library linking)
- **Project.swift**: Create sourceless targets (`sources: []`) that link to SPM libraries (`dependencies: [.external(name: "JasonetteApp-iOS")]`)
- **Result**: `.xcodeproj` with code signing, bundle ID, assets — ready for Archive → TestFlight

## Minimum Viable Implementation

### 1. Package.swift

```swift
let package = Package(
    name: "JasonetteApp",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Jasonette", targets: ["Jasonette"]),
        .library(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"]),
        .library(name: "JasonetteApp-macOS", targets: ["JasonetteApp-macOS"]),
    ],
    targets: [
        .target(name: "Jasonette", path: "Sources/Jasonette"),
        .target(name: "JasonetteApp-iOS", dependencies: ["Jasonette"], path: "Sources/JasonetteApp-iOS"),
        .target(name: "JasonetteApp-macOS", dependencies: ["Jasonette"], path: "Sources/JasonetteApp-macOS"),
        .testTarget(name: "JasonetteTests", dependencies: ["Jasonette"], path: "Tests/JasonetteTests"),
    ]
)
```

### 2. App.swift (per platform)

```swift
import SwiftUI
import Jasonette

@main
public struct JasonetteApp: App {
    public init() {}
    public var body: some Scene {
        WindowGroup { JasonetteNavigationView(...) }
    }
}
```

**File locations**:
- `Sources/JasonetteApp-iOS/App.swift`
- `Sources/JasonetteApp-macOS/App.swift`

### 3. Project.swift (Tuist)

```swift
import ProjectDescription

let project = Project(
    name: "Jasonette",
    targets: [
        .target(
            name: "Jasonette-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.example.jasonette",
            deploymentTargets: .iOS("16.0"),
            sources: [],  // Crucial: empty sources
            resources: ["Resources/iOS/**"],
            dependencies: [.external(name: "JasonetteApp-iOS")]  // Crucial: link SPM library
        ),
        // ... more targets for macOS, tvOS, visionOS
    ]
)
```

### 4. Tuist/Package.swift (bridge)

```swift
import PackageDescription

#if TUIST
import ProjectDescription
let packageSettings = PackageSettings(productTypes: [:])
#endif

let package = Package(
    name: "JasonetteDependencies",
    dependencies: [.package(path: "..")]
)
```

## Verification Checklist

- [ ] `swift build` completes without errors
- [ ] `swift test` passes all tests
- [ ] `tuist generate` creates `.xcodeproj`
- [ ] `.xcodeproj` has 4 targets (Jasonette-iOS, macOS, tvOS, visionOS)
- [ ] Each target has `sources: []` in build settings
- [ ] Each target has external dependency on matching SPM library
- [ ] `xcodebuild` can build for simulator
- [ ] `xcodebuild archive` creates `.xcarchive`
- [ ] Xcode can upload to TestFlight

## Common Issues and Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| `ld: symbol not found for architecture arm64: _main` | Missing SPM link | Add `.external(name: "...")` to dependencies |
| "Cannot find 'JasonetteApp' in scope" | App struct is internal | Make struct `public` |
| "Program does not contain definition of `main`" | Sources not empty | Set `sources: []` |
| Assets missing in app | Resources path wrong | Use `resources: ["Resources/iOS/**"]` |
| `swift test` fails | Tests can't import platform lib | Tests only depend on core `Jasonette` lib |
| Tuist can't find SPM package | Wrong Package.swift path | Use `.package(path: "..")` in `Tuist/Package.swift` |

## Useful Commands

```bash
# SPM development
swift build
swift test
swift build -c release

# Tuist
tuist generate
tuist clean

# Xcode
xcodebuild -project Jasonette.xcodeproj -target Jasonette-iOS build
xcodebuild -project Jasonette.xcodeproj -target Jasonette-iOS archive

# Inspection
xcodebuild -project Jasonette.xcodeproj -target Jasonette-iOS -showBuildSettings
```

## Architecture Diagram

```
┌─────────────────────────────────────┐
│     Tuist Project.swift             │
│  ┌─────────────────────────────────┐│
│  │ Sourceless shell targets        ││
│  │ (code signing, bundle ID, etc)  ││
│  └─────────────────────────────────┘│
│    ↓ (links to)
│  ┌─────────────────────────────────┐│
│  │ External SPM library products   ││
│  │ (JasonetteApp-iOS, etc.)        ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
    ↓ (depends on)
┌─────────────────────────────────────┐
│     Package.swift (SPM)             │
│  ┌─────────────────────────────────┐│
│  │ Core library: Jasonette         ││
│  │ Platform libs: App.swift @main  ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
    ↓ (uses)
┌─────────────────────────────────────┐
│  Business Logic + UI Components     │
│  (SwiftUI, networking, data model)  │
└─────────────────────────────────────┘
```

## Why This Pattern Works

1. **SPM is fast** — compile, test, iterate in <1 second
2. **Platform libs decouple entry point** — @main is public, linkable by Tuist
3. **Tuist provides deployment** — .xcodeproj has code signing, bundle ID, assets
4. **No code duplication** — core logic shared via single dependency
5. **No circular dependencies** — tests depend on Jasonette only, not platform libs
