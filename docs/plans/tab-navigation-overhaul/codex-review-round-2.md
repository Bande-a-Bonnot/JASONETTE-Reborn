> **Status:** historical. Findings here are round-2 (pre-shell)
> observations; most have since been addressed in the shipped PR #20
> shell (lazy-mount via `mounted: Set<TabID>`, `TabDescriptor(from:)`
> scheme allowlist, `entryURL`-preferring promotion, `$reload` seed
> consumed once, etc.). Call-outs on each finding below note whether
> it landed in PR #20 or remains open.

## Findings

- **BLOCKER (fixed in PR #20)**: Bootstrap preloading breaks reload semantics on the root document. [JasonetteRootView.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteRootView.swift#L60) fetches the entry doc, [JasonetteNavigationView.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteNavigationView.swift#L90) then instantiates `JasonetteView(document:)`, and [JasonetteViewModel.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteViewModel.swift#L83) only refetches when `document == nil`. In `.single` mode, and for the bootstrap tab in `.tabs`, `$reload`, pull-to-refresh without `$pull`, and retry paths stop hitting the network and just re-render the stale in-memory document.

- **BLOCKER (fixed in PR #20)**: Promotion can select a non-selectable tab and boot into a blank shell. [JasonetteNavigationCoordinator.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteNavigationCoordinator.swift#L39) falls back to `entries.first!` without requiring a document tab, [TabShellState.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/TabShellState.swift#L14) accepts that selection, and [JasonetteTabShell.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteTabShell.swift#L49) renders `.web/.app/.action` tabs as `Color.clear`. A footer whose first item is non-document, or whose tabs are all non-document, launches with an empty content area.

- **HIGH (fixed in PR #20)**: All document tabs are live-loaded immediately, even when hidden. Shell now uses `mounted: Set<TabID>` and renders hidden tabs as `Color.clear` until first selection. [JasonetteTabShell.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteTabShell.swift#L20) mounts every tab scope up front, [JasonetteView.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift#L30) runs `loadIfNeeded()` for every mounted root view, and [JasonetteView.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift#L123) only tears down timers on disappear. Hidden tabs therefore fetch, run `$load`, and keep timers alive before the user ever selects them.

- **HIGH (fixed in PR #20)**: Footer-tab taps bypass the renderer’s existing URL/view validation. `TabDescriptor(from:)` now enforces the same scheme allowlist as `handleHref`. The old path validates schemes in [JasonetteViewModel.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteViewModel.swift#L150). The new shell builds tab targets from any `URL(string:)` in [JasonetteNavigationCoordinator.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteNavigationCoordinator.swift#L108) and opens/selects them directly in [JasonetteTabShell.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteTabShell.swift#L63). That reintroduces blocked/custom-scheme opens for `web/app` tabs and turns invalid document URLs into selectable error states instead of ignored taps.

- **HIGH (fixed in PR #20)**: Tab icon extraction is wrong for normal tabs. `TabDescriptor.init?(from:)` now reads `item.image` directly instead of `item.imageURL`. [JasonetteNavigationCoordinator.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/JasonetteNavigationCoordinator.swift#L96) stores `iconURL` from `item.imageURL`, but [JasonDocument.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonDocument.swift#L88) defines `imageURL` as `url ?? image`. For a standard footer tab with both a target `url` and an `image`, the icon becomes the document URL, so [FooterTabBar.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/FooterTabBar.swift#L40) tries to render JSON as an image.

- **MEDIUM (fixed in PR #20)**: The package no longer exposes the broken
  entry point. `JasonetteNavigationView`, `JasonetteView`, and
  `NavigationRequest` were demoted to `internal` in `cbd1ef9`; external
  callers must use `JasonetteRootView(url:)`, which drives the one-shot
  `.single → .tabs` promotion through the coordinator.

## Questions

- The UUIDv7 comment claims later IDs sort after earlier ones, but [UUIDv7.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/UUIDv7.swift#L3) only guarantees cross-millisecond ordering; within the same millisecond the ordering is random. [TabNavigationCoordinatorTests.swift](../../../JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/TabNavigationCoordinatorTests.swift#L15) sleeps 2ms, so it never exercises the risky case. I would not rely on monotonic ordering from this implementation.

- `transition:"switch"` to a non-selectable tab currently behaves as a miss and falls through to in-stack push via [JasonetteNavigationView.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteNavigationView.swift#L115) and [TabShellState.swift](../../../JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/TabShellState.swift#L36). If that is intentional, fine; if authors expect parity with tapping a `web/app` tab, it is not implemented.

The current tests pass because they mostly pin coordinator state, not end-to-end shell behavior. There is no coverage for bootstrap-tab reload/pull, non-selectable-first-tab boot, eager hidden-tab loading, tab-tap validation, or tab icon parsing.
