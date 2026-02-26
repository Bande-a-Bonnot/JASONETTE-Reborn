---
title: "SwiftUI & Compose: Future-Proofing the UI Framework Stack"
date: 2026-02-26
status: decided
updates_plan: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
---

# SwiftUI & Compose: Future-Proofing the UI Framework Stack

## What We're Building

Jasonette renders JSON into native UI components. The previous plan recommended UIKit (iOS) and RecyclerView (Android) — proven but aging frameworks. This brainstorm explored whether to use SwiftUI and Jetpack Compose instead, to future-proof the stack.

## Why This Matters

- UIKit and RecyclerView are in maintenance mode — Apple and Google invest in SwiftUI/Compose
- New contributors in 2026 expect modern declarative frameworks
- A greenfield rewrite is the one chance to pick the right foundation for the next decade

## Key Decisions

### 1. iOS: Hybrid — UICollectionView + UIHostingConfiguration

**Decision:** Use UICollectionView + CompositionalLayout for the scrolling/recycling engine, with SwiftUI views as cell content via `UIHostingConfiguration` (iOS 16+).

**Why not pure SwiftUI:**
- `LazyVStack` does not recycle views — memory accumulates, fast-scroll to distant positions forces instantiation of all intermediate items
- `List` recycles (backed by UICollectionView since iOS 16) but is too opinionated for SDUI styling
- No production SDUI framework uses pure SwiftUI for list rendering

**Why not pure UIKit:**
- SwiftUI is the future — new iOS developers learn SwiftUI first
- `UIHostingConfiguration` lets us write all visible UI in SwiftUI while UIKit handles recycling
- This is the pattern used by Duolingo (ReactiveCollectionsKit) and HEMA (58 SDUI components in production)

**Architecture:**
```
JSON from server
  -> Component Registry (maps type strings to Swift types)
    -> UICollectionView + CompositionalLayout
      -> DiffableDataSource
        -> UIHostingConfiguration { SwiftUI cell content }
```

**Navigation:** `UINavigationController` for push/pop, `present()` for modals. SwiftUI `NavigationStack` is not used because `NavigationLink` doesn't work inside `UIHostingConfiguration`.

**Key implementation rules:**
- Always set `.id(item.id)` on root SwiftUI view inside `UIHostingConfiguration` to prevent reuse identity bugs
- No `NavigationLink` inside cells — handle selection via UICollectionView delegate
- Lift `@State` out of cell views into external store (recycling resets `@State`)
- No nesting lazy containers inside cells (causes layout loops)

### 2. Android: Jetpack Compose (LazyColumn)

**Decision:** Use Jetpack Compose with `LazyColumn` as the primary rendering engine. No RecyclerView.

**Why Compose over RecyclerView:**
- `LazyColumn` already recycles items natively — no hybrid approach needed (unlike SwiftUI)
- Compose handles dynamic/data-driven UI more naturally than SwiftUI — no `AnyView` type erasure, just call composables dynamically
- Jetpack Compose is the standard for new Android apps in 2026
- Greenfield project — no legacy RecyclerView adapters to maintain

**Architecture:**
```
JSON from server
  -> Component Registry (maps type strings to Kotlin composables)
    -> LazyColumn with dynamic composable dispatch
      -> when(component.type) { "label" -> LabelComponent(data) ... }
```

**Navigation:** Compose Navigation or Activity-based, depending on complexity.

### 3. Web: TypeScript (unchanged)

No change from the existing plan. Vanilla `document.createElement` with Vite build.

### 4. Template Engine: TypeScript Now, Shared Rust Core Later

**Decision:** Write the template engine (JSEP + AST walker) in TypeScript first for the web platform. Port patterns to Swift and Kotlin for native platforms. Later, rewrite the core in Rust and share via UniFFI (iOS/Android) and wasm (web).

**Why TypeScript first:**
- Fastest iteration cycle
- Web is the first platform to ship
- TypeScript implementation becomes the specification for native ports

**Why Rust later (not now):**
- Rust + UniFFI + wasm is a proven cross-platform sharing strategy (Mozilla, 1Password, Signal)
- Eliminates maintaining 3 implementations of the highest-risk component
- No JS runtime overhead on native platforms (unlike the "run JS everywhere" approach)
- But: adding Rust to the build chain is significant complexity — defer until v1.1+

### 5. Compose Multiplatform for iOS: Rejected

**Decision:** Do not use Compose Multiplatform to target iOS.

**Why:**
- Adds ~9MB to iOS binary
- Renders via Skia/Metal, not native UIKit — doesn't feel fully native
- High CPU and memory consumption reported on iOS (issue #4912)
- No hot reload for iOS targets
- Kotlin-to-Swift interop is awkward

## What This Changes in the Plan

| Plan Section | Old | New |
|---|---|---|
| Phase 2.1 (iOS project setup) | "UIKit for list/table rendering engine" | UICollectionView + CompositionalLayout + UIHostingConfiguration for lists; SwiftUI for cell content, modals, non-list screens |
| Phase 2.2 (iOS core framework) | "UIKit or SwiftUI" | SwiftUI via UIHostingConfiguration for components; UINavigationController for navigation |
| Phase 2.3 (iOS components) | "UILabel or SwiftUI Text" | SwiftUI `Text`, `Image`, `Button`, etc. rendered inside UIHostingConfiguration |
| Phase 3.1 (Android project setup) | "RecyclerView for list/table rendering" | Jetpack Compose `LazyColumn` |
| Phase 3.2 (Android core framework) | "QuickJS or Rhino" for expressions | Jetpack Compose for UI; QuickJS still for `$script.*` |
| Phase 3.3 (Android components) | "TextView or Compose Text" | Compose `Text`, `Image`, `Button`, etc. |
| Research Insights: iOS | "Recommend pure UIKit for v1.0" | Hybrid UICollectionView + UIHostingConfiguration |
| Research Insights: Android | "Recommend pure RecyclerView" | Jetpack Compose LazyColumn |
| Effort Estimates | Template engine: port to Swift + Kotlin | Template engine: TS now, Rust core later |

## Open Questions

1. **Minimum iOS version:** UIHostingConfiguration requires iOS 16. The plan already targets iOS 16 — confirmed compatible.
2. **Minimum Android SDK:** Jetpack Compose requires minSdk 21. The plan targets 26 — confirmed compatible.
3. **Rust timeline:** When does the Rust core become worth the build complexity? Likely after v1.0 when all 3 platform implementations exist and divergence becomes painful.
4. **ReactiveCollectionsKit:** Should we use Duolingo's library or write our own thin UICollectionView wrapper? Evaluate at implementation time.

## References

- [HEMA SDUI Migration (Q42 Engineering)](https://engineering.q42.nl/swiftui-hema-app/) — 58 components, production
- [ReactiveCollectionsKit (Duolingo)](https://github.com/jessesquires/ReactiveCollectionsKit) — production UICollectionView wrapper
- [UIHostingConfiguration (Apple Docs)](https://developer.apple.com/documentation/swiftui/uihostingconfiguration) — iOS 16+
- [Backend-Driven SwiftUI (Jacob Bartlett)](https://blog.jacobstechtavern.com/p/backend-driven-swiftui) — SDUI patterns
- [SwiftUI Cell Reuse Identity (Lucas van Dongen)](https://lucasvandongen.dev/swiftui_uitableviewcell_reuse_id.php) — gotcha
- [Compose Multiplatform 1.8.0 Stable (JetBrains)](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released/) — why we rejected CMP for iOS
- [List or LazyVStack (Fatbobman)](https://fatbobman.com/en/posts/list-or-lazyvstack/) — recycling analysis
