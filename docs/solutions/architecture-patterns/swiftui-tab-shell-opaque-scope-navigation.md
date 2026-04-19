---
title: "SwiftUI tab shell treats each tab as an opaque navigable scope"
date: 2026-04-19
category: architecture-patterns
tags: [swiftui, navigation, tabs, state-restoration, scenestorage, identity]
module: Jasonette
symptom: "Tab switch destroys @StateObject VMs, wipes nav paths, breaks modals, leaks timers"
severity: design-pattern
resolution_time: "4 atomic commits + 1 review-followup commit"
related:
  - docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md
  - docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md
---

# SwiftUI Tab Shell: Opaque Per-Tab Navigable Scopes

## Context

Jasonette's iOS renderer originally had one `JasonetteNavigationView` that tried to own both tab switching AND per-tab navigation. It tracked `@State currentRoot: URL` and forced identity swaps on tab change via `.id(currentRoot)`. That worked until anything other than the trivial happy path happened:

- `@StateObject JasonetteViewModel` was destroyed on every tab switch — timers leaked, `$load` lifecycle fired on every switch, in-flight fetches cancelled mid-render.
- The per-tab `@State path: [URL]` was wiped, so pushed pages vanished when the user switched back.
- Modal sheets bound to `@State modalURL` got torn down.
- `transition:"switch"` hrefs deep inside a pushed page had no clean way to reach the top-level tab switcher.

The instinctive fix — "have the shell own per-tab `NavigationStack` paths" — was wrong. That trades one coupling (identity owned by content) for another (navigation state owned by shell). Two model reviews (Codex gpt-5.4 at xhigh, Opus 4.7 subagent) both recommended that approach and both were rejected by the user: "Who says a tab is a NavigationView / NavStack / Whatever? What's the point of the view holding the tab view even knowing about each tab's internal nav?"

## Guidance

**The shell owns selection. Each tab owns its own navigation. The shell never peers inside.**

Split the hosting into three layers with strict ownership boundaries:

```
JasonetteRootView              // bootstraps; owns coordinator
  ├── .single mode            // one nav view, no tab bar
  │     JasonetteNavigationView
  └── .tabs mode              // N tabs + persistent bar
        JasonetteTabShell
          ├── FooterTabBar    // presentation-only
          └── ZStack of N JasonetteNavigationView
                              // each a self-contained scope:
                              //   @State path: [URL]
                              //   @State modalURL
                              //   @StateObject VM
```

Key ownership rules:

- **Shell**: owns `selectedTabID`, `tabs: [TabEntry]`, env closures, `@SceneStorage` selection key. Does NOT own per-tab paths, modal slots, VMs, scroll positions.
- **Per-tab `JasonetteNavigationView`**: owns everything about navigation inside that tab. Stays mounted for the life of the shell scene so state persists across re-selections.
- **Coordinator**: owns the `.single → .tabs` promotion (one-way, idempotent). Decides the initial selection based on the entry URL. Stays in `.single` if the bootstrap document declares no document tabs.

### Shell-internal mechanisms

**Identity preservation via ZStack + opacity.** The shell hosts all selected tabs in a ZStack and toggles `.opacity`/`.allowsHitTesting`/`.accessibilityHidden` rather than mounting/unmounting. SwiftUI's structural identity stays stable, so `@StateObject` VMs persist.

**Lazy mount for hidden tabs.** Mounting all N tabs up front means all N fetch immediately, run `$load`, and hold timers before the user picks one. Instead, render `Color.clear` until the tab is first selected; once mounted, it stays mounted for the rest of the scene. Tracked via `@State private var mounted: Set<TabID>`.

**Tab selection persistence via canonical key.** `TabID` is a per-launch UUIDv7 — useless for `@SceneStorage`. Instead persist `TabDescriptor.target.canonicalKey` (e.g. `"doc:https://…/tab.json"`), which is stable across launches. On restore, look up whether that key still matches a currently-selectable tab; if yes, use it, otherwise fall back to the coordinator's entry-URL match.

**Cross-scope switch via environment closure.** A `transition:"switch"` href deep inside a pushed page needs to reach the shell. The shell injects an env closure `(URL) -> Bool`; the nav view calls it from its dispatch path and falls back to `.push` when the closure returns false (no matching tab). Default is a no-op that returns false, so single-stack mode naturally handles the same case by falling through to push.

### Bootstrap contract

- Coordinator starts in `.single(rootURL:, preloadedDoc: nil)`.
- First document fetch finishes → `bootstrapDidLoad(doc:)` inspects `body.footer.tabs`.
- If non-empty AND contains at least one document tab: promote to `.tabs(shell:, bootstrapDoc:, bootstrapURL:)`. Initial selection is the first selectable tab matching the entry URL, falling back to the first selectable tab.
- If empty OR all tabs are `.web/.app/.action`: stay in `.single(rootURL:, preloadedDoc: doc)` so the single fetched doc is available for first render without a second round-trip.
- Promotion is one-way. Re-declaring tabs after bootstrap is ignored.

### Preload-seed reload semantics

When the shell passes the bootstrap doc into a tab to avoid a duplicate fetch, the VM must distinguish "seed present, render without fetch" from "subsequent reload, refetch from URL." Otherwise `$reload`, retry, and pull-to-refresh-without-`$pull` forever re-render the stale seed.

```swift
private var seedConsumed: Bool = false

func load() async {
    loadState = .loading
    let hasUnconsumedSeed = document != nil && !seedConsumed
    if let url, !hasUnconsumedSeed {
        document = try await loader.load(from: url)
    }
    seedConsumed = true
    // …render, fire $load, etc.
}
```

### Input validation at descriptor construction

Scheme allowlist enforcement must happen when building a `TabDescriptor` from raw JSON, not only at navigation time. Otherwise a tab advertising `file:///etc/passwd` is rendered in the bar, and tapping it invokes `openURL` on whatever was declared — reintroducing exactly the class of bug the href path already guards against.

## Why This Matters

Once the shell stops peeking at per-tab nav state, a whole class of problems disappears:

- **State survives tab switches** by construction. The tab's VM, path, and modal slot live in the same `JasonetteNavigationView` instance across all switches.
- **Deep-link switching is trivial.** `switchToURLIfMatches(url: URL) -> Bool` is 4 lines. A miss is a legitimate signal — fall through to `.push`.
- **Restoration is a string lookup.** No TabID plumbing across launches, no versioned schema for the persisted selection.
- **Adding a new tab kind** (action-dispatch tabs, web tabs) requires only a new `TabDescriptor.Target` case and a branch in the shell's tap handler. No changes to any tab's internal nav logic.
- **Each tab's error modes are local.** A fetch failure in tab 3 doesn't cascade; tab 3 shows its own error state while the other tabs keep working.

The rejected alternative (shell owns per-tab stacks) forces the shell to know how every tab navigates, which means every new navigation capability (modals, action hrefs, deep-link routing inside a tab) has to be plumbed through the shell's type system. That's a leaky abstraction that inverts the relationship — tabs should be opaque to the shell, not the other way around.

## When to Apply

Apply this pattern whenever you have:

1. A persistent bar (tabs, side rail, navigation sidebar) that switches between isolated content scopes.
2. Per-scope state that must survive scope switches — view models, scroll positions, in-flight requests, modal presentations.
3. Cross-scope signals (e.g. "switch to tab X from deep inside tab Y") that need to route without the sender knowing the shell's internals.

Do NOT apply when:

- Scopes are stateless and can be cheaply rebuilt on switch. SwiftUI's built-in `TabView` works fine.
- The tab bar is the app's only navigable structure and there's no per-tab stack. Use `TabView(selection:)`.

## Examples

### Before (broken)

```swift
struct JasonetteNavigationView: View {
    @State private var currentRoot: URL
    @State private var path: [URL] = []
    @StateObject private var vm: JasonetteViewModel

    var body: some View {
        NavigationStack(path: $path) {
            JasonetteView(url: currentRoot, …)  // rebuilt on every tab switch
                .id(currentRoot)                 // destroys VM on switch
        }
    }

    // switchRoot from footer tab tap
    func dispatch(_ r: NavigationRequest) {
        if case .switchRoot(let url) = r {
            currentRoot = url   // wipes path, destroys VM, leaks timers
            path = []
        }
    }
}
```

### After (correct)

```swift
// Shell: knows about selection only.
struct JasonetteTabShell: View {
    @ObservedObject var shell: TabShellState
    @SceneStorage("jasonette.selectedTab") private var storedKey: String = ""
    @State private var mounted: Set<TabID> = []

    var body: some View {
        ZStack {
            ForEach(shell.tabs) { tab in
                let selected = tab.id == shell.selectedTabID
                content(for: tab)
                    .opacity(selected ? 1 : 0)
                    .allowsHitTesting(selected)
            }
        }
        .safeAreaInset(edge: .bottom) { FooterTabBar(...) }
        .environment(\.jasonetteSwitchTab) { url in
            shell.switchToURLIfMatches(url)
        }
        .onChange(of: shell.selectedTabID) { newID in
            storedKey = shell.selectedCanonicalKey
            mounted.insert(newID)
        }
    }
}

// Each tab: a self-contained nav scope. Mounted once, kept alive.
struct JasonetteNavigationView: View {
    @State private var path: [URL] = []
    @StateObject private var vm: JasonetteViewModel
    @Environment(\.jasonetteSwitchTab) private var switchTab

    func dispatch(_ r: NavigationRequest) {
        switch r {
        case .switchTab(let url):
            if !switchTab(url) { path.append(url) }  // miss = push, per design
        // …
        }
    }
}
```

## Related

- `docs/plans/tab-navigation-overhaul/plan.md` — the implementation plan that produced this pattern.
- `docs/plans/tab-navigation-overhaul/codex-gpt-5.4-xhigh.md` — Codex's initial review proposing shell-owned stacks (rejected).
- `docs/plans/tab-navigation-overhaul/opus-4.7.md` — Opus 4.7's review proposing a similar shell-owned stacks design (also rejected).
- `docs/plans/tab-navigation-overhaul/codex-review-round-2.md` — Codex's follow-up review after implementation, which caught the preload-seed reload bug, non-selectable initial selection, eager hidden-tab loads, and missing scheme validation.
