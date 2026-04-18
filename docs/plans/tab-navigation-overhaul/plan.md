---
title: "Tab navigation overhaul (hybrid plan)"
date: 2026-04-18
status: proposed
scope: iOS renderer (JasonetteApp SPM core)
reviews:
  - codex-gpt-5.4-xhigh.md
  - opus-4.7.md
---

# Tab navigation overhaul — hybrid plan

## Decision

Adopt Codex's shell bar (custom `safeAreaInset`) but **reject the claim that
the shell owns per-tab navigation stacks**. Both reviewers conflated "each
tab's state must survive selection changes" (correct) with "the shell holds
the stack" (wrong). The stack belongs inside the navigable unit, not above it.

**Corrected model:**

- Each tab's content is an opaque `JasonetteNavigationView(url:)` — already
  "one navigable scope, one path, one modal slot." Its navigation state is
  its own private business.
- The shell owns: selection + an ordered list of `TabEntry`s (descriptor
  only — target URL, icon, badge, style). No paths. No `StackState`. No
  `NavigationStack(path:)` at the shell level.
- Tabs stay mounted in a `ZStack` with opacity/hit-testing so each
  `JasonetteNavigationView`'s `@State` and `@StateObject` survive selection
  changes — same identity preservation, without the shell knowing anything
  about each tab's internals.
- Deep-descendant "switch tabs" requests (e.g. `transition: "switch"` from a
  button inside a tab's pushed detail) route up via a single env closure,
  `jasonetteSwitchTab: (URL) -> Bool`. The descendant asks; the shell
  decides; nothing in between.

Rationale for the custom bar (unchanged from first draft):

- Jasonette's JSON-driven presentation (remote PNG icons, author-controlled
  fonts/colors/badges, action-only items, runtime `$render` tab diffs) fights
  `.tabItem` at every turn. Legacy ObjC Jasonette rendered its own bar for
  this reason.
- Native `TabView` would buy cross-platform adaptation for free but cost us
  authorial control over every pixel of the bar — the wrong trade for this
  codebase.

## Non-goals (explicitly deferred)

- Runtime `$render` tab diffs (v1: tabs locked at bootstrap).
- `@SceneStorage` restoration of per-tab paths (v1: selected tab only).
- `Route(UUIDv7)` identity.
- iPad/visionOS sidebar adaptation.
- Cross-session tab persistence.

Deferral is documented in each new type's comment so future work is discoverable.

## Current failure modes (from both reviews)

Anchored to existing files so migration steps are grounded:

1. `JasonetteNavigationView.swift:60` — `.id(currentRoot)` destroys
   `@StateObject viewModel`, `StateManager`, timers, `$load` state, scroll
   position on every tab tap.
2. `JasonetteNavigationView.swift:33-34` — single `path: [URL]` +
   `currentRoot: URL` shared across tabs; Tab A's pushed history dies on
   every Tab B tap.
3. `JasonetteNavigationView.swift:100-103` — `switchRoot` is the wrong
   primitive; tab selection is not a navigation request.
4. `JasonetteView.swift:217-253` — `footerView` renders the tab bar *inside*
   `documentBody`, so the bar flickers on every re-render and disappears on
   pushed pages whose docs lack `footer.tabs`.
5. `JasonetteView.swift:329-…` — `FooterTabItemView` synthesizes
   `transition = "switch"` for tapped tabs, leaking shell concerns into a
   presentation component.
6. `JasonetteViewModel.swift:163-166` — `handleHref` routes `transition ==
   "switch"` to `.switchRoot(url)`; no tab-index resolution, no reselect
   detection, no "match-against-declared-tabs" check.
7. `FooterTabItemView` has no selected-state — users can't tell which tab
   they're on.

## Target architecture

### Types (new)

```swift
// TabID — stable identity per tab. UUIDv7 per project convention.
// NEVER key tabs by URL; two tabs can target the same doc.
public struct TabID: Hashable, Sendable {
    let value: UUID  // v7
}

// TabDescriptor — canonical target + presentation spec. Hashable so we can
// dedupe at bootstrap and match for transition:"switch".
struct TabDescriptor: Hashable, Sendable {
    let target: Target
    let label: TabLabelSpec
    enum Target: Hashable, Sendable {
        case document(URL)             // normal tab
        case web(URL)                   // opens Safari; does NOT select
        case app(URL)                   // opens externally; does NOT select
        case action(JasonAction)        // fires action; does NOT select
    }
}

struct TabLabelSpec: Hashable, Sendable {
    let text: String?
    let iconURL: URL?
    let badge: String?
    let style: JasonStyle?              // author-declared colors/fonts
}

// TabEntry — descriptor + id. NO path, NO stack. Content is opaque.
struct TabEntry: Identifiable, Sendable {
    let id: TabID
    let descriptor: TabDescriptor
}

// TabShellState — the entire shell-side state. Selection + list of entries.
// The shell does not know what's inside each tab.
@MainActor
final class TabShellState: ObservableObject {
    @Published var selectedTabID: TabID
    let tabs: [TabEntry]
    init(tabs: [TabEntry], initialSelection: TabID)
    func select(_ id: TabID)            // reselect → scroll-top signal (phase 2)
    func switchToURLIfMatches(_ url: URL) -> Bool
}

// JasonetteNavigationCoordinator — top-level. Owns the mode transition
// (single → tabs, once, on bootstrap). Never demotes.
@MainActor
final class JasonetteNavigationCoordinator: ObservableObject {
    enum Mode {
        case single(rootURL: URL, preloadedDoc: JasonDocument?)
        case tabs(TabShellState, bootstrapDoc: JasonDocument, bootstrapURL: URL)
    }
    @Published var mode: Mode
    let entryURL: URL
    init(entryURL: URL)
    func bootstrapDidLoad(doc: JasonDocument)
    func switchToURLIfTab(_ url: URL) -> Bool
}
```

Notably absent (deliberately):

- No `StackState`. Stacks live inside each `JasonetteNavigationView`.
- No `JasonetteStackHost`. We render `JasonetteNavigationView` directly.
- No `path` bindings threaded through the shell.
- No per-tab `ObservableObject` holding a path.

### View tree

```swift
// NEW public entry point. JasonetteNavigationView is kept INTERNAL as the
// "one navigable scope" primitive it should have been all along.
public struct JasonetteRootView: View {
    @StateObject private var coordinator: JasonetteNavigationCoordinator
    public init(url: URL) {
        _coordinator = StateObject(wrappedValue: .init(entryURL: url))
    }
    public var body: some View {
        switch coordinator.mode {
        case .single(let url, let preloaded):
            JasonetteNavigationView(url: url, preloadedDoc: preloaded)
                .onReceiveLoadedDoc { doc in coordinator.bootstrapDidLoad(doc: doc) }

        case .tabs(let shell, let bootstrapDoc, let bootstrapURL):
            JasonetteTabShell(
                shell: shell,
                bootstrapDoc: bootstrapDoc,
                bootstrapURL: bootstrapURL
            )
        }
    }
}

// The shell. Opaque tab content via a @ViewBuilder. Selection + bar only.
struct JasonetteTabShell: View {
    @ObservedObject var shell: TabShellState
    let bootstrapDoc: JasonDocument       // passed to the matching tab; no refetch
    let bootstrapURL: URL
    var body: some View {
        ZStack {
            ForEach(shell.tabs) { tab in
                tabContent(tab)                       // JasonetteNavigationView(url:)
                    .opacity(tab.id == shell.selectedTabID ? 1 : 0)
                    .allowsHitTesting(tab.id == shell.selectedTabID)
                    .accessibilityHidden(tab.id != shell.selectedTabID)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTabBar(
                tabs: shell.tabs,
                selectedTabID: shell.selectedTabID,
                onTap: { shell.select($0) }
            )
        }
        .environment(\.jasonetteIsInsideTabShell, true)
        .environment(\.jasonetteSwitchTab) { shell.switchToURLIfMatches($0) }
    }

    @ViewBuilder
    private func tabContent(_ tab: TabEntry) -> some View {
        switch tab.descriptor.target {
        case .document(let url):
            JasonetteNavigationView(
                url: url,
                preloadedDoc: url == bootstrapURL ? bootstrapDoc : nil
            )
        case .web, .app, .action:
            Color.clear     // action-tabs have no content; tap is handled in the bar
        }
    }
}
```

`JasonetteNavigationView` (internal, post-migration) is stripped to its
proper job:

```swift
@MainActor
struct JasonetteNavigationView: View {
    @State private var path: [URL] = []
    @State private var modalURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    let rootURL: URL
    let preloadedDoc: JasonDocument?      // new — used on bootstrap tab only
    private let onClose: (() -> Void)?     // set when presented as a sheet
    // NO currentRoot, NO .id(), NO switchRoot case.
    var body: some View { ... }
}
```

### Environment keys (new)

```swift
private struct JasonetteIsInsideTabShellKey: EnvironmentKey {
    static let defaultValue = false
}
private struct JasonetteSwitchTabKey: EnvironmentKey {
    static let defaultValue: (URL) -> Bool = { _ in false }
}
extension EnvironmentValues {
    var jasonetteIsInsideTabShell: Bool { ... }
    var jasonetteSwitchTab: (URL) -> Bool { ... }
}
```

`JasonetteView.footerView` checks `jasonetteIsInsideTabShell` and suppresses
its own `footer.tabs` branch when `true`. `JasonetteViewModel.handleHref`
calls `jasonetteSwitchTab(url)` for `transition == "switch"`; falls back to
`.push` on `false`.

## Rules (invariants the design enforces)

- The tab bar lives outside document content, via `safeAreaInset(edge: .bottom)`.
- Each tab owns its own `StackState`. Selection changes never touch stacks.
- Tab identity is by `TabID` (UUIDv7), never by URL.
- Pushed pages inside a tab ignore their own `footer.tabs` (env-gated).
- `$back` at a tab root is a no-op. It does not switch tabs.
- Reselect (same tab tapped twice) pops that tab's stack to root and emits a
  scroll-top signal (phase 2 — scaffold the signal now, wire consumers later).
- Modals present above the tab bar (iOS default with `.sheet`).
- Duplicate tab targets are rejected: debug asserts, release keeps first.
- Action-only tabs (`item.action` set, no URL) dispatch the action and do NOT
  change `selectedTabID`.

## Atomic migration order

Each step is one commit (or small PR) on its own.

### Step 1 — Scaffolding (no behavior change)

- Add `TabID`, `TabDescriptor`, `TabLabelSpec`, `TabEntry` value types.
- Add `TabShellState`, `JasonetteNavigationCoordinator` observable objects.
- Add env keys `jasonetteIsInsideTabShell`, `jasonetteSwitchTab`.
- Add `UUIDv7` helper (CLAUDE.md mandates v7 strictly; the codebase has one
  existing `UUID()` call we'll leave for a separate pass).
- Unit tests: mode transitions, selection, `switchToURLIfMatches` matching,
  duplicate-target dedupe, URL-not-in-tabs handling.
- **No** UI wiring yet. `JasonetteNavigationView` / `JasonetteView` unchanged.
- Files: NEW `Rendering/Navigation/*.swift`.

### Step 2 — Clean `JasonetteNavigationView` to its proper job

- Add `preloadedDoc: JasonDocument?` param to `JasonetteNavigationView` and
  thread it through to `JasonetteView`.
- Delete `NavigationRequest.switchRoot`.
- Delete `@State currentRoot`, `.id(currentRoot)` on the root destination.
- `JasonetteNavigationView.init(url:)` becomes `init(url:, preloadedDoc:)`
  (default `nil`) — the public signature stays compatible.
- `JasonetteViewModel.handleHref` + env: `transition == "switch"` now reads
  `@Environment(\.jasonetteSwitchTab)` and calls it; on `false`, falls through
  to `.push`. (Requires env-read in the VM — either a closure captured in
  `onNavigate` by the view, or a new `NavigationRequest.switchTab(URL)`
  routed via existing dispatch. Favor the request variant for test parity.)
- `FooterTabItemView` stops synthesizing `transition = "switch"`. Tab cells
  in the old footer path are no longer tapped (Step 3 moves them out
  entirely); this step just removes the synthesis so nothing is broken mid-
  migration.
- Update `testHandleHrefTransitionSwitchEmitsSwitchRoot` → rename + assert
  `.switchTab(url)` is emitted; add fall-through-to-push test.
- Files: `JasonetteNavigationView.swift`, `JasonetteViewModel.swift`,
  `JasonetteView.swift` (FooterTabItemView), `ViewModelTests.swift`.

### Step 3 — Root view + tab shell rendering

- NEW `JasonetteRootView(url:)` public entry point.
- NEW `JasonetteTabShell` renders `ZStack` of tab content (opaque —
  `JasonetteNavigationView(url:)` for `.document`, `Color.clear` for action
  tabs) + `safeAreaInset(edge: .bottom)` `FooterTabBar`.
- NEW `FooterTabBar` — presentational only. Active highlight driven by
  `selectedTabID`. No href synthesis.
- Bootstrap: `JasonetteRootView` starts in `.single(entryURL)` mode.
  `JasonetteNavigationView` gets a callback (env closure, not prop) to hand
  the loaded root `JasonDocument` back up. Coordinator inspects
  `doc.body.footer.tabs` and promotes to `.tabs` exactly once.
- On promotion, the tab whose `.document(url)` matches `entryURL` is mounted
  with `preloadedDoc` so no refetch happens.
- `JasonetteView.footerView` guards the tabs branch with
  `jasonetteIsInsideTabShell` (ignore tabs once we're in the shell).
- Update iOS/macOS/tvOS/visionOS app entry points from
  `JasonetteNavigationView` → `JasonetteRootView`.
- Tests: shell renders correct content, reselect → `select(id)` called on
  already-selected tab (hook for scroll-top later), pushed pages do not
  re-render the bar.
- Files: NEW `Rendering/Navigation/JasonetteRootView.swift`,
  `JasonetteTabShell.swift`, `FooterTabBar.swift`; MOD `JasonetteView.swift`,
  `JasonetteApp-*.swift`.

### Step 4 — Edge cases + polish

- `view: "web" | "app"` tab items → tap opens URL (Safari on iOS,
  `openURL` elsewhere). Selection unchanged.
- Action-only tabs (`descriptor.target == .action`): tap fires the action,
  selection unchanged.
- `$back` at a tab root: no-op (guard `!path.isEmpty`).
- Modal presentation above the shell: `.sheet` at the navigation-view level
  already covers the bar (iOS default).
- Duplicate target rejection: `#if DEBUG assertionFailure()`; release keeps
  first.
- Entry URL not in declared tabs: first tab selected, bootstrap doc
  discarded, debug-assert.
- `@SceneStorage("jasonette.selectedTab")` for selection only (paths
  deferred).
- Tests for each edge case.

### Step 5 — Cleanup

- Delete old `FooterTabItemView` and its tab branch in
  `JasonetteView.footerView`. `FooterTabBar` is the only tab-bar renderer.
- Delete `NavigationRequest.switchTab` if the env-closure path made it
  redundant.
- Update `docs/HANDOFF.md`, `CLAUDE.md` patterns.
- Write `docs/solutions/navigation-routing/tab-shell-architecture-2026-04.md`
  capturing the "shell owns selection, not stacks" lesson.

## Files touched (summary)

NEW:

- `Sources/Jasonette/Rendering/Coordinator/JasonetteNavigationCoordinator.swift`
- `Sources/Jasonette/Rendering/Coordinator/StackState.swift`
- `Sources/Jasonette/Rendering/Coordinator/TabShellState.swift`
- `Sources/Jasonette/Rendering/Coordinator/TabDescriptor.swift`
- `Sources/Jasonette/Rendering/Environment.swift`
- `Sources/Jasonette/Rendering/FooterTabBar.swift`
- `Tests/JasonetteTests/CoordinatorTests.swift`
- `Tests/JasonetteTests/TabShellStateTests.swift`

MODIFIED:

- `Sources/Jasonette/Rendering/JasonetteNavigationView.swift` — rewrite.
- `Sources/Jasonette/Rendering/JasonetteView.swift` — footer suppression,
  preloadedDoc init, delete `FooterTabItemView`.
- `Sources/Jasonette/Rendering/JasonetteViewModel.swift` — env closure
  switch path.
- `Tests/JasonetteTests/ViewModelTests.swift` — `switchRoot` → switchTab
  rename, fall-through test.

DELETED (in step 5 or 7):

- `NavigationRequest.switchRoot` case.
- `FooterTabItemView` (old).
- `.id(currentRoot)` + `@State currentRoot`.

## Open questions for the user

1. **Action-only tabs.** Legacy ObjC Jasonette: any precedent for tabs that
   fire `$href` / `$action` without changing selection? Or is this hypothetical?
   If hypothetical, de-scope step 6a.
2. **`view: "web"` / `view: "app"` in tab position.** Rare? If nobody uses
   this shape, reject it at bootstrap rather than building around it.
3. **Reselect scroll-top.** The legacy app scrolled the root ScrollView to
   top on reselect. Ship the signal in step 4 but defer consumers to a later
   pass? (`ScrollViewReader` wiring touches every scroll root.)
4. **Tab descriptor canonical target.** URL equality ignoring query /
   fragment, or strict? Affects duplicate detection + `switchToURLIfTab`
   matching.

## Review sources

- `docs/plans/tab-navigation-overhaul/codex-gpt-5.4-xhigh.md` — architecture
  (shell ownership, bootstrap promotion, `safeAreaInset` bar, per-tab stacks).
- `docs/plans/tab-navigation-overhaul/opus-4.7.md` — diagnosis (14 concrete
  failure modes), pragmatic v1 data model, action-only-tab analysis.
