---
title: "Tuist 4 crashes with 'Duplicate values for key' when Tuist/Package.swift references the project root"
date: 2026-03-07
category: build-errors
tags: [tuist, spm, xcode, tuist-4, local-package]
module: JasonetteApp
symptom: "Fatal error: Duplicate values for key: '/path/to/project' during tuist generate"
---

# Tuist 4: Duplicate Key Crash with Local SPM Package

## Problem

`tuist generate` crashes with:

```
Swift/arm64e-apple-macos.swiftinterface:17075: Fatal error: Duplicate values for key: '/path/to/JasonetteApp'
```

## Root Cause

Tuist 4 auto-discovers the root `Package.swift`. When `Tuist/Package.swift` also declares `.package(path: "..")`, both resolve to the same absolute path. Tuist builds an internal dictionary keyed by path and crashes on the duplicate.

## What Doesn't Work

### Tuist/Package.swift bridge (Tuist 3 pattern)

```swift
// Tuist/Package.swift — CRASHES in Tuist 4
let package = Package(
    name: "Dependencies",
    dependencies: [.package(path: "..")]  // resolves to project root = duplicate
)
```

### #if TUIST in root Package.swift + .external(name:)

Adding `#if TUIST` block to the root Package.swift and using `.external(name:)` in target dependencies produces:

```
`JasonetteApp-iOS` is not a valid configured external dependency
```

Root Package.swift products are local, not "external."

## What Works

Remove `Tuist/Package.swift` entirely. Use `packages:` parameter in Project.swift with `.local(path: ".")`:

```swift
let project = Project(
    name: "Jasonette",
    packages: [
        .local(path: "."),  // reference root Package.swift directly
    ],
    settings: .settings(base: [...]),
    targets: [
        .target(
            name: "Jasonette-iOS",
            product: .app,
            sources: [],
            dependencies: [.package(product: "JasonetteApp-iOS")],  // not .external()
        ),
    ]
)
```

Key differences from Tuist 3:
- **No `Tuist/Package.swift`** — delete it
- **`packages: [.local(path: ".")]`** in Project.swift — must come before `settings:`
- **`.package(product:)`** not `.external(name:)` for target dependencies

## Prevention

- When upgrading to Tuist 4, grep for `Tuist/Package.swift` with local path references and convert to `packages:` inline
- If `packages:` argument order causes compile errors, check Swift initializer parameter ordering — `packages:` must precede `settings:` in the `Project()` call
