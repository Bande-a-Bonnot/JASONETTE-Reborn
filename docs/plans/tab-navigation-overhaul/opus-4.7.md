I've read the code. Noting the reminders; proceeding with the review without additional file reads.

# Tab Navigation Overhaul Proposal

## 1. Diagnosis — you're right, and it's worse than you said

Current `JasonetteNavigationView` treats tabs as "replace the stack root." That's not what tabs are. Tabs are `N` parallel navigation stacks that the user flips between. Replacing the root on every tap is the core architectural sin, and everything below cascades from it.

**Concrete failures, most of them load-bearing:**

1. **State is destroyed on every tab tap.** `JasonetteView` owns a `@StateObject private var viewModel`. SwiftUI attaches `@StateObject` lifetime to view identity. `.id(currentRoot)` at the top is a nuke — every tab switch changes the identity, SwiftUI tears down the view, the `@StateObject` is deallocated, `StateManager` (which holds `local` state), `ActionDispatcher` timers, `$load` lifecycle, scroll position, focus, keyboard — gone. Come back to Tab A → you get a fresh network fetch and a fresh `$load`. That alone is "completely fucked up."

2. **Path is shared across tabs.** `@State var path: [URL]` is a single array. Tab A pushes detail → tap Tab B → `path = []` wipes Tab A's stack. Return to Tab A → you land on the root, not the detail you were reading. Classic UITabBarController preserves per-tab stacks. We preserve zero.

3. **The tab bar is inside the scrolling document.** `footerView` is rendered from `documentBody`, which is rebuilt every time `renderedRoot` changes, every time we switch tab, every time a pushed page comes in. It flickers because it's literally a different `View` instance every time. It also means each pushed page needs to re-declare the footer in its JSON to keep the tab bar visible, which is not how the legacy Obj-C app worked and not what authors expect.

4. **Pushed pages hide the tab bar.** When you push Tab A → Detail, the detail view is a different document with no `footer.tabs`. The bar disappears. Legacy Jasonette: tab bar sticks across pushes within a tab.

5. **No active-tab indicator at all.** `FooterTabItemView` has no concept of "am I the selected tab" — no highlight, no color change, no SF-symbol-filled-vs-outline. Users can't tell which tab they're on.

6. **`switchRoot` does not find the matching tab.** Even if you fix (2), the switch semantics just clobber `currentRoot`. If the user was already in Tab B, pushed 3 pages deep, then tapped Tab B again, "classic" iOS pops to root. Current code doesn't distinguish "switch to same tab" from "switch to different tab."

7. **`transition: "switch"` is synthesized by the tab item.** `FooterTabItemView` defaults `transition = "switch"` when the author didn't specify one. That's a structural concern leaking into what should be a presentation-only component. The legacy Jasonette didn't require `transition: "switch"` in JSON — tab-ness was a property of *where the href lived*, not a transition flag.

8. **Chicken-and-egg bootstrap.** `JasonetteNavigationView.init(url:)` accepts one URL. Tabs live in the fetched body. The first fetch doesn't happen until a `JasonetteView` appears. So the tab bar can't be declared at the navigation-container level — we only discover tabs after rendering, deep inside the subtree. The current design renders the footer per-page as a consequence, not a choice.

9. **Modals from a tab detail don't cover the tab bar correctly.** The root `.sheet(item: $modalURL)` is on the `NavigationStack`'s container — because the tab bar lives inside `documentBody` (inside the stack), a sheet will fully cover it, which matches iOS semantics *by accident*. But when the tab bar moves up (correctly) to outside the stack, you have to consciously keep sheets above the tab bar. iOS `TabView` does this for free; a custom bar does not.

10. **`onDisappear { viewModel.actionDispatcher.invalidateAllTimers() }`** fires when the user switches tab. Tab A's timers die. Come back to Tab A → timers don't restart (no `$foreground`/re-`$load` plumbing). Another correctness bug cascading from the teardown model.

11. **`.task { await viewModel.loadIfNeeded() }` re-fires when identity changes.** Combined with `loadState == .idle` gate it's "only-once per instance," but because the instance dies on every tab switch, you pay a full network load per visit. Caching of `DocumentLoader` might mask it, but semantically it's wrong.

12. **Deep link into a tab URL doesn't light that tab up.** If the app opens with `url = TabB.url`, there's no tab array yet. When tabs are discovered and rendered, nothing connects "current document URL equals TabB's URL" to "selected tab index = 1."

13. **`#if os(iOS)` guards `.navigationBarTitleDisplayMode`.** Fine for the content, but `TabView` + `NavigationStack` behavior diverges on macOS/tvOS/visionOS — today the design ignores this; any overhaul must pick a cross-platform story.

14. **Two tabs with the same URL.** `path` is a `[URL]`, `NavigationStack` uses `URL` as the destination type. If two tabs both point at `demo.json`, switching between them via `switchRoot` becomes ambiguous, and if `Hashable` ever hits collisions with destination identity it's a latent bug.

## 2. Overhaul — architecture

### Where the tab bar lives

**Top of the tree, in a `TabView(selection:)`, above N `NavigationStack`s — one per tab.** Use the native `TabView`. Stop reinventing.

Reasons:

- `TabView` preserves children across selection changes. Each child (a `NavigationStack`) keeps its `@State`, its `@StateObject` view models, its scroll position. That's the UITabBarController semantic, gift-wrapped.
- `TabView` renders the bar outside the stack, so pushed detail pages see it automatically.
- `TabView` handles modal-over-tab-bar correctly and cross-platform (`tabViewStyle(.sidebarAdaptable)` on macOS/visionOS gives you the right affordance for free).
- `.tabItem` drives the native bar. We use SwiftUI's built-in label/image/badge APIs instead of hand-rolling `AsyncImage` + `ZStack` + caption styling.

The tab item's `image` from JSON is a remote PNG URL — `.tabItem` expects a `Label`/`Image`. We pre-fetch those via `AsyncImage` inside `.tabItem` (works), or we map known icons to SF Symbols with a fallback. Ship `AsyncImage`-in-tabItem; it's supported and matches the JSON contract.

### How state is preserved

Each tab gets:

- Its own `NavigationStack` with its own `@State path: [URL]` — placed as a struct child of the `TabView` so `TabView` owns its identity and persists it.
- Its own root `JasonetteView` which owns its `@StateObject JasonetteViewModel` as today. Because the tab view is not destroyed, the VM survives.
- A `@SceneStorage("tab.N.path")` if we want the stacks to restore across app relaunches (nice-to-have; ship later).

**Delete `.id(currentRoot)`**. Identity stability is the whole point.

### Bootstrap — the chicken and egg

You need the tabs before you can render the `TabView`, and you need to render something to fetch the tabs. Solve by **two-phase render**:

1. `JasonetteRootView(url:)` — a new top-level container. Pre-fetches the entry URL with a lightweight loader (the existing `DocumentLoader`), NOT via `JasonetteView`, so no VM lifecycle commitment.
2. While loading: `ProgressView`.
3. On success: inspect `doc.body.footer.tabs.items`.
   - If tabs exist: render `JasonetteTabContainer(tabs: items, initialTabIndex: 0)` — it builds the `TabView` with N `NavigationStack`s, one per tab URL. The entry URL is the first tab if it matches one; otherwise it becomes the root of tab 0 and the tabs array replaces nothing (it's an authorial choice — document below).
   - If no tabs: render the current `JasonetteNavigationView`-equivalent — a bare `NavigationStack` wrapping one `JasonetteView`.
4. On error: error UI with Retry.

The entry URL *often is* one of the tab URLs (legacy Jasonette's convention is that the first tab `==` the initial document). When it matches, we mount that tab directly with the already-fetched document (skip the second fetch). When it doesn't, pick tab 0 and log; do not try to be clever.

### Pushed detail pages with their own `footer.tabs`

**Ignore them.** The tab bar is fixed at the tab-container level and is derived from the initial document's tabs. A pushed detail's `footer.tabs` is not promoted. This matches legacy Jasonette: tabs are a property of the app shell, not of individual pages.

Concretely: when `JasonetteView` renders inside a pushed destination, `footerView` skips `tabs` entirely and only handles `input` (or other non-tab footers). That's a one-line guard: "am I inside a tab container? then no tabs."

Pass an `@Environment(\.jasonetteIsInsideTabContainer) var` boolean — `true` when rendered as a tab root, propagated down the `NavigationStack`. Pushed views see `true` and suppress their own tab rendering. Standalone `JasonetteView` (no tabs in the doc) sees `false` and is free.

### Active-tab highlighting

`TabView` handles this natively via selection binding. We maintain `@State var selectedTab: Int` and bind `TabView(selection: $selectedTab)`. The system paints the selected tab.

**Deep-linking into a tab URL**: `JasonetteTabContainer` computes `initialTabIndex` at mount time by matching the entry URL against `tabs.items[*].href.url || items[*].url`. If it matches, start selected on that tab. If not, start on 0. This is the minimum correct behavior; richer deep-link matching (sub-paths, query) is a TODO.

### Modals

Keep `.sheet(item:)` at the tab-container level, one per tab's `NavigationStack`. `TabView` handles sheet-above-tab-bar correctly (sheet covers the whole screen including the bar, classic iOS). Sheet-from-within-a-pushed-page: same — the push is inside the tab's `NavigationStack`, the sheet presents at stack level, `TabView` still covers the tab bar with the sheet.

We already have `JasonetteNavigationView` carrying a sheet-scoped recursive presentation (sheet presents another `JasonetteNavigationView`). Reuse that — but rename to `JasonetteNavigationStack` (what it actually is) and have the tab container mount one per tab. The *recursive* sheet-presenting-a-nav-stack behavior stays; it's correct for "open a modal with its own navigation."

### EXACT view tree

```swift
// NEW: top-level entry. Replaces direct use of JasonetteNavigationView.
public struct JasonetteRootView: View {
    let url: URL
    @State private var bootstrap: BootstrapState = .loading

    enum BootstrapState {
        case loading
        case tabbed(initialDoc: JasonDocument, tabs: [JasonTabDescriptor], initialIndex: Int)
        case single(initialDoc: JasonDocument)   // no tabs
        case error(String)
    }

    public var body: some View {
        switch bootstrap {
        case .loading:
            ProgressView().task { await bootstrapFetch() }
        case .tabbed(let doc, let tabs, let idx):
            JasonetteTabContainer(initialDoc: doc, tabs: tabs, initialIndex: idx)
        case .single(let doc):
            JasonetteNavigationStack(root: .document(doc))
        case .error(let msg):
            ErrorView(message: msg, retry: { bootstrap = .loading })
        }
    }
}

// NEW: the tab shell. Owns selection, one NavigationStack per tab.
struct JasonetteTabContainer: View {
    let initialDoc: JasonDocument
    let tabs: [JasonTabDescriptor]   // parsed from initialDoc.body.footer.tabs
    @State var selectedIndex: Int
    @State var paths: [[URL]]        // per-tab stacks, length == tabs.count

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, tab in
                JasonetteNavigationStack(
                    root: i == initialIndex && tab.url == initialDoc.sourceURL
                        ? .document(initialDoc)               // skip refetch
                        : .url(tab.url),
                    path: $paths[i],
                    isInsideTabContainer: true
                )
                .tabItem { TabItemLabel(tab) }
                .badge(tab.badge)
                .tag(i)
            }
        }
        .onChange(of: selectedIndex) { old, new in
            // Pop-to-root convention: tapping the already-selected tab clears its stack.
            if old == new { paths[new].removeAll() }
        }
        .environment(\.jasonetteIsInsideTabContainer, true)
    }
}

// RENAMED + SIMPLIFIED from JasonetteNavigationView.
// Still owns a NavigationStack + a sheet. No more switchRoot. No more currentRoot.
struct JasonetteNavigationStack: View {
    enum Root { case url(URL), document(JasonDocument) }

    let root: Root
    @Binding var path: [URL]               // external when inside tab, internal otherwise
    @State private var modalURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: URL.self) { url in
                    JasonetteView(url: url, onNavigate: dispatch)
                }
        }
        .sheet(item: $modalURL) { item in
            JasonetteNavigationStack(root: .url(item.url), onClose: { modalURL = nil })
        }
        #if os(iOS)
        .sheet(item: $safariURL) { SafariView(url: $0.url).ignoresSafeArea() }
        #endif
    }

    @ViewBuilder private var rootView: some View {
        switch root {
        case .url(let u):       JasonetteView(url: u, onNavigate: dispatch)
        case .document(let d):  JasonetteView(document: d, onNavigate: dispatch)
        }
    }

    // dispatch: push/modal/back/close/web/app identical to today.
    // switchRoot is GONE from this layer — it's the tab container's job.
    // If a push somehow receives .switchRoot, route it up via a new
    // environment closure to the tab container, or ignore outside tabs.
}
```

### The tab descriptor

```swift
struct JasonTabDescriptor {
    let index: Int
    let url: URL?              // derived from href.url ?? item.url
    let title: String?
    let imageURL: URL?
    let badge: String?
    let action: JasonAction?   // for action-only tabs (rare but possible)
    let view: String?          // "web" / "app" / nil
}
```

Parse once at bootstrap. Do not re-derive from `JasonComponent` deep in the view tree.

## 3. What dies, what survives

### Delete

- `NavigationRequest.switchRoot` — entire case. Tab switching is not a navigation request; it's a `TabView` selection change driven directly by the tab container.
- `FooterTabItemView` — replaced by a `TabItemLabel` that's only used inside `.tabItem { }`. Half the file goes.
- `footerView`'s `tabs` branch in `JasonetteView` — the tab bar is no longer rendered inside a document. Keep only the `input` branch. Guard with "if inside tab container, ignore tabs entirely."
- `FooterTabItemView`'s defaulting of `transition = "switch"` — gone. Tab taps don't go through `handleHref` at all.
- `@State var currentRoot: URL` in the nav view — gone. Root is immutable per nav stack now.
- `.id(currentRoot)` — gone.
- Current `JasonetteNavigationView.init(url:)` top-level API — replaced by `JasonetteRootView(url:)`. Keep `JasonetteNavigationView` as a thin back-compat alias for one release if anything external calls it, then delete.

### Rewrite

- `JasonetteNavigationView` → `JasonetteNavigationStack`. Same responsibility minus tab-switching, plus an external `@Binding path` for the tab-container case.
- `handleHref` in the VM: the `transition == "switch"` branch stops producing `.switchRoot`. It either (a) gets removed entirely, or (b) becomes an environment-driven request routed to the tab container for "programmatic switch to tab matching URL X." Pick (b); it's a real feature (e.g. `$href` to a tab URL from a button).

### Survives unchanged

- `JasonetteViewModel` — all of it, except the `switchRoot` case in `handleHref`.
- `NavigationRequest.push/modal/back/close/web/app` — unchanged.
- `JasonDocument` / `JasonTabs` / `JasonComponent` — data model doesn't change.
- `JasonetteView`'s rendering of sections, layers, header, input-footer — unchanged.

## 4. Concrete SwiftUI APIs used, and why

- **`TabView(selection:)`**: native tab bar, native per-child state preservation, native cross-platform adaptation. Non-negotiable.
- **`.tabItem { Label / Image }`** and **`.badge(_:)`**: native bar entries; get accessibility, dynamic type, platform styling for free. Using an `HStack` at the bottom of a `ScrollView` (today's design) throws all of that away.
- **`.tag(_:)`**: binds the tab to its selection value. Use `Int` index — URLs aren't `Hashable`-unique across tabs that point at the same doc, and strings would be fragile.
- **`NavigationStack(path:)` per tab**: independent stacks, independent back buttons, independent titles. Works inside `TabView` without ceremony.
- **`@StateObject`** for `JasonetteViewModel` inside each `JasonetteView`: same as today. The key is view identity stability — which `TabView` provides for us.
- **`@State var paths: [[URL]]`** at the tab container: owned by one view, passed by `@Binding` into each `JasonetteNavigationStack`. Parent-owned so the pop-to-root tap behavior works (the container needs to mutate the selected tab's path).
- **`@Environment(\.jasonetteIsInsideTabContainer)`**: a private `EnvironmentKey` so deeply-nested `JasonetteView`s know to suppress their `footer.tabs` rendering. Cleaner than drilling a prop.
- **`@Environment(\.openURL)`**: unchanged for `app` hrefs.
- **`.sheet(item:)`**: unchanged for modals and Safari.
- **`@SceneStorage("jasonette.selectedTab")`** (optional, phase 2): persist selection across app launches. Per-tab path storage is trickier (`[URL]` isn't naturally `SceneStorage`-compatible) — skip for v1.
- **`AsyncImage` inside `.tabItem`**: supported. For remote PNGs this is the pragmatic path. If we want to be nicer, cache via an `ImageLoader` and only inject a ready `Image` — phase 2.

Do **not** use `@SceneStorage` for paths v1 (serialization of `URL` arrays is fine but re-resolving stale doc URLs after an offline relaunch is a whole extra failure mode). Do **not** use `NotificationCenter` (your own MEMORY.md says no — global broadcast has no scope).

## 5. Edge cases the new design must handle

| Case | Behavior | How |
|---|---|---|
| Tab item with `view: "web"` | Do NOT switch tabs; open Safari. | In `TabItemLabel`/selection path: the tab container detects `tab.view == "web"` and, instead of changing selection, calls `openURL(tab.url)` (iOS: presents `SafariView`). The tab stays visually unselected or we reject the selection in `onChange(of:)` by reverting. Easier: render these "tabs" as a distinct bar item that dispatches an href instead of participating in `TabView` selection. Honestly — deprecate `view:web` inside tabs; it's an abuse of the shape. Document it. |
| Tab item with `view: "app"` | Same as above with `openURL`. | Same pattern. |
| Deep link with `transition: "switch"` (programmatic `$href` to a tab URL) | Switch to the tab whose URL matches. If no match, push. | VM emits a new `NavigationRequest.switchTab(URL)` (replacing `.switchRoot`). The tab container installs an environment closure `switchToURL: (URL) -> Bool`. VM calls it; if it returns `true`, switch happened and we're done; if `false`, fall back to `.push`. |
| Deep link with no `transition` to a tab URL | Push on the current tab's stack, even if the URL coincidentally matches another tab. | Current tab's `path.append(url)`. Authors wanting tab-switching must say so. This is legacy-Jasonette behavior; do not auto-promote pushes to switches. |
| `$back` from a pushed page inside a tab | Pop current tab's stack. | `NavigationRequest.back` → `path.removeLast()` — `path` is the current tab's binding. No change from today, just now scoped correctly. |
| `$back` at a tab root (empty stack) | No-op. Do NOT switch tabs. | Guard `!path.isEmpty` (already there). |
| `$close` at a tab root | No-op (we're at the app shell). | `onClose` is `nil` when not inside a sheet. |
| `$close` inside a modal | Dismiss the modal. | Unchanged; the sheet's `JasonetteNavigationStack` carries `onClose`. |
| Tab item with no `url`, no `href`, but an `action` | Tap fires the action without switching tabs. | Replace `.tag(i)` behavior with a custom bar? No — `.tabItem` doesn't support non-selecting items. Action-only tabs must be handled with a custom bar fallback *only* for the action-tab case, OR we rule them out in the JSON contract. Recommendation: render them as normal tabs that, on selection, fire the action and revert selection. Ugly but predictable. |
| Same tab URL tapped twice (already selected) | Pop that tab's stack to root. | `.onChange(of: selectedIndex)` — if `old == new` isn't detected (selection change fires only on actual change), mirror-tap can be caught by binding through a custom `get/set` that detects equal-assign and clears the path before forwarding. |
| Two tabs with the same URL | Work correctly — selection is by `Int` index, not URL. | `.tag(i)` with `Int` index handles this. Never key tabs by URL. |
| Tabs change at runtime (`$render` produces a different `footer.tabs`) | Do NOT rebuild the tab bar. | v1 contract: tabs are fixed at bootstrap. A `$render` that changes tabs is ignored for tab-bar purposes. Document it. Legacy parity: legacy Jasonette also locks tabs at the app level. |
| Initial URL not in the tab list | Start on tab 0; the initial URL becomes tab 0's first pushed page OR we push it on tab 0 after selection. | Prefer: tab 0's root is `tabs[0].url`, then we push the initial URL on top (so the user sees what they deep-linked to, with a back button home). Call this out in docs. |
| Landscape / iPad / visionOS | `TabView` adapts — sidebar on iPad Regular width if we use `.tabViewStyle(.sidebarAdaptable)`. | Opt in for v1 on iOS 18+; fallback to `.tabViewStyle(.automatic)` otherwise. |
| Nav bar background color from `header.style.background` | Unchanged — each tab's root applies it via the existing `.toolbarBackground` chain. | No change required; the chain is per-`NavigationStack`. |
| Pushed page declares its own `footer.tabs` | Ignored. | Environment flag `jasonetteIsInsideTabContainer == true` makes `JasonetteView.footerView` skip the `tabs` branch. |
| Loading failure on bootstrap | Show error with retry. | Handled in `JasonetteRootView.BootstrapState.error`. |

## 6. Public API surface

### New

```swift
public struct JasonetteRootView: View {
    public init(url: URL)
}
```

This replaces `JasonetteNavigationView(url:)` as the canonical app entry point.

### Internal (was public)

```swift
struct JasonetteNavigationStack: View {
    enum Root { case url(URL), document(JasonDocument) }
    init(root: Root,
         path: Binding<[URL]>? = nil,           // nil => uses internal @State
         onClose: (() -> Void)? = nil,
         isInsideTabContainer: Bool = false)
}

struct JasonetteTabContainer: View {
    init(initialDoc: JasonDocument,
         tabs: [JasonTabDescriptor],
         initialIndex: Int)
}
```

### Environment

```swift
private struct JasonetteIsInsideTabContainerKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var jasonetteIsInsideTabContainer: Bool {
        get { self[JasonetteIsInsideTabContainerKey.self] }
        set { self[JasonetteIsInsideTabContainerKey.self] = newValue }
    }
}

private struct JasonetteSwitchTabKey: EnvironmentKey {
    static let defaultValue: (URL) -> Bool = { _ in false }
}
extension EnvironmentValues {
    var jasonetteSwitchTab: (URL) -> Bool {
        get { self[JasonetteSwitchTabKey.self] }
        set { self[JasonetteSwitchTabKey.self] = newValue }
    }
}
```

VM consults `jasonetteSwitchTab` in `handleHref` for `transition == "switch"`; if it returns `true`, done; if `false` (no tab container or no matching tab), fall through to `.push`.

### `NavigationRequest`

- Delete `.switchRoot(URL)`.
- Add (optional, if you want the env closure to be uniform): `.switchTab(URL)` — routed through `dispatch` to call the env closure. Either is fine; environment-closure is cleaner because it skips the dispatch indirection.

### Tests to rewrite

- `testHandleHrefTransitionSwitchEmitsSwitchRoot` — rename, assert `switchTab` or that the env closure was called.
- Add: tab container preserves per-tab path across selection changes; selecting already-selected tab clears its path; deep-link into a tab URL selects that tab; pushed page's `footer.tabs` is suppressed.

---

## Migration order (don't do this in one PR)

1. Add `JasonetteRootView` + `JasonetteTabContainer` + `JasonetteNavigationStack` alongside the old view. Old code keeps working.
2. Flip the app entry point (`JasonetteApp-iOS/-macOS/...`) to `JasonetteRootView`.
3. Delete `.id(currentRoot)`, `switchRoot`, the tab branch in `footerView`, and `FooterTabItemView`.
4. Update tests.
5. Rename `JasonetteNavigationView` → `JasonetteNavigationStack` in a cleanup PR.

Each step is an atomic commit per the project conventions.

---

## Files touched

- `/Users/thomas/Projects/Banade-a-Bonnot/JASONETTE-Reborn/JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteNavigationView.swift` — replace with `JasonetteNavigationStack`, delete `switchRoot`.
- `/Users/thomas/Projects/Banade-a-Bonnot/JASONETTE-Reborn/JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift` — delete `FooterTabItemView`, gate `footerView`'s tabs branch on the env flag.
- `/Users/thomas/Projects/Banade-a-Bonnot/JASONETTE-Reborn/JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteViewModel.swift` — replace `switchRoot` branch in `handleHref` with env-closure path.
- NEW: `Sources/Jasonette/Rendering/JasonetteRootView.swift`.
- NEW: `Sources/Jasonette/Rendering/JasonetteTabContainer.swift`.
- NEW: `Sources/Jasonette/Rendering/JasonetteEnvironment.swift` (env keys).
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/ViewModelTests.swift` — update `switch` test; new file `TabContainerTests.swift`.

## Bottom line

The current design pretended tabs are a kind of navigation. They aren't. Tabs are N parallel view hierarchies with independent state; navigation happens *inside* each. Move the tab bar to a native `TabView` at the top of the tree, give each tab its own `NavigationStack`, stop destroying identity on selection, and the fifteen bugs you're seeing collapse into zero. The rest is cleanup.
