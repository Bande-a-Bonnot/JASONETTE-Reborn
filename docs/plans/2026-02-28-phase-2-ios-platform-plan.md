---
title: "Phase 2: iOS Platform"
type: feat
date: 2026-02-28
status: in-progress
parent: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
milestone: 5
branch: feat/phase-2-ios-platform
---

# Phase 2: iOS Platform

## Goal

Native iOS app that renders `$jason` JSON using modern Swift. Uses UICollectionView +
CompositionalLayout for scrolling/recycling, SwiftUI via UIHostingConfiguration for
component UI, and UINavigationController for navigation.

## Deliverables

1. **Xcode project** — Swift, iOS 16+, SPM-only dependencies
2. **Template engine** — Port JSEP + AST walker to Swift (expression evaluator)
3. **Component rendering** — SwiftUI views for all Tier 1 components
4. **Layout system** — UICollectionView CompositionalLayout
5. **Action system** — Structured concurrency, success/error chaining
6. **Navigation** — UINavigationController push/modal/tabs
7. **Lifecycle hooks** — $load, $show, $foreground, $pull

## Tasks

### 2.1 — Xcode Project Setup

- [ ] Create `JASONETTE-iOS/JasonetteApp/` Swift package structure
- [ ] Package.swift with iOS 16+ deployment target
- [ ] App entry point (UIKit lifecycle, not SwiftUI App)
- [ ] `jasonette.config.json` loader for root URL
- [ ] PrivacyInfo.xcprivacy

### 2.2 — Template Engine (Swift Port)

- [ ] JSEP-style expression tokenizer/parser in Swift
- [ ] AST walker with same security layers (property blocklist, complexity limits)
- [ ] `{{var}}` interpolation, `{{#each}}`, `{{#if}}`/`{{#else}}`
- [ ] Safe function allowlist (same as TypeScript)
- [ ] Unit tests matching TypeScript conformance suite

### 2.3 — Core Architecture

- [ ] `JasonDocument` model (Codable structs matching $jason schema)
- [ ] `DocumentLoader` — URLSession fetch + JSON decode + template rendering
- [ ] `ComponentRegistry` — protocol mapping type strings to SwiftUI views
- [ ] `ActionDispatcher` — async/await with success/error chaining
- [ ] `StateManager` — $get/$set (in-memory), $cache (UserDefaults)
- [ ] `StyleResolver` — Jasonette style → SwiftUI modifiers

### 2.4 — Components (SwiftUI)

- [ ] `LabelComponent` — SwiftUI Text
- [ ] `ImageComponent` — AsyncImage
- [ ] `ButtonComponent` — SwiftUI Button
- [ ] `TextFieldComponent` — SwiftUI TextField
- [ ] `TextAreaComponent` — SwiftUI TextEditor
- [ ] `HtmlComponent` — WKWebView via UIViewRepresentable
- [ ] `SliderComponent` — SwiftUI Slider
- [ ] `SpaceComponent` — Spacer
- [ ] `SwitchComponent` — SwiftUI Toggle
- [ ] `MapComponent` — MapKit Map (stub)

### 2.5 — Layout & Rendering

- [ ] UICollectionView + CompositionalLayout
- [ ] DiffableDataSource for animated updates
- [ ] UIHostingConfiguration for SwiftUI cells
- [ ] Vertical section layout
- [ ] Horizontal section layout
- [ ] Section headers
- [ ] Layers (overlay)

### 2.6 — Navigation

- [ ] UINavigationController push (default)
- [ ] Modal presentation (present())
- [ ] Tab-based navigation (UITabBarController)
- [ ] SFSafariViewController for view: "web"
- [ ] UIApplication.open for view: "app"
- [ ] Back/close navigation

### 2.7 — Actions (Tier 1)

- [ ] $render, $reload
- [ ] $network.request (URLSession)
- [ ] $set/$get, $cache.*
- [ ] $util.alert (UIAlertController), $util.toast, $util.banner
- [ ] $timer.start/$timer.stop
- [ ] $log, $lambda, $flush

### 2.8 — Lifecycle & Polish

- [ ] $load (viewDidLoad)
- [ ] $show (viewDidAppear)
- [ ] $foreground (UIScene willEnterForeground)
- [ ] $pull (UIRefreshControl)
- [ ] Error screen for invalid JSON/unreachable URL
- [ ] App Transport Security (HTTPS default)

### 2.9 — Testing & CI

- [ ] XCTest unit tests for template engine
- [ ] XCTest unit tests for components
- [ ] XCTest unit tests for actions
- [ ] Snapshot tests for rendered views
- [ ] CI: xcodebuild in GitHub Actions
