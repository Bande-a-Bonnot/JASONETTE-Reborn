---
title: "Swift #if canImport() vs #if os() for iOS-only frameworks"
date: 2026-03-08
category: build-errors
tags: [swift, swiftui, safariservices, canImport, platform-check, cross-platform]
module: iOS Components
symptom: "macOS build fails with 'SFSafariViewController is unavailable' despite #if canImport(SafariServices) guard"
root_cause: "canImport(SafariServices) is true on macOS (framework exists in SDK) but SFSafariViewController is iOS-only"
severity: build-error
---

# `#if canImport()` vs `#if os()` for iOS-Only Frameworks

## Problem

When guarding iOS-specific code like `SFSafariViewController`, using `#if canImport(SafariServices)` compiles on macOS because the SafariServices framework *exists* in the macOS SDK — it just doesn't contain the same types.

```swift
// BROKEN: compiles on macOS, then fails at type resolution
#if canImport(SafariServices)
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    // SFSafariViewController is iOS-only — macOS build error
}
#endif
```

The macOS SDK includes SafariServices with `SFSafariApplication` (for Safari extensions), so `canImport` evaluates to `true`. But `SFSafariViewController` only exists on iOS/iPadOS.

## Fix

Use `#if os(iOS)` for types that are platform-exclusive, not just framework-exclusive:

```swift
#if os(iOS)
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
#endif
```

## When to Use Each

| Guard | Use When |
|-------|----------|
| `#if os(iOS)` | Type is iOS-exclusive (`UIKit` views, `SFSafariViewController`, `UIKeyboardType`) |
| `#if canImport(X)` | Framework may not exist at all (e.g., third-party SPM package, `HealthKit` on tvOS) |
| `#if os(iOS) \|\| os(tvOS)` | Type exists on a subset of Apple platforms |

## Lesson

`canImport` answers "does the framework exist in the SDK?" — not "do all the types I need exist on this platform?" For Apple frameworks that share a name across platforms but differ in contents, use `#if os()`.
