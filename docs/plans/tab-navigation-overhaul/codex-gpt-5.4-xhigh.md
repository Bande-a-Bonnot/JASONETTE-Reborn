## Verdict

This is not a bug fix. It is a navigation-model rewrite. The current implementation is fundamentally incompatible with tab semantics because it models the whole app as one stack plus one mutable root.

## Diagnosis

- `JasonetteNavigationView` currently behaves like a single-stack browser, not a tab controller. A tab controller needs one persistent shell plus one independent stack per tab.
- `path: [URL]` is the wrong model. A route is not just a URL. It needs stable identity, presentation style, and the ability to represent the same URL multiple times.
- `currentRoot` plus `.id(currentRoot)` is a state-destruction bomb. It guarantees loss of `@StateObject`, `StateManager`, timers, scroll position, in-flight async work, and any cached root document.
- Tab switching is happening through content navigation (`FooterTabItemView -> handleHref -> switchRoot`) when it should be a shell concern. Content should not own tab-controller semantics.
- Rendering the tab bar inside `documentBody` is structurally wrong. It ties app chrome to scrollable content, causes flicker, breaks safe-area behavior, and makes pushed pages accidentally control shell visibility.
- One global stack means there is no UITabBarController parity: no preserved per-tab history, no stable tab root, no correct back behavior, no correct deep linking, no reselect behavior.
- There is no stable active-tab identity. Without that, highlight state, reselect handling, restoration, and deep-link routing all stay brittle.
- The current model will race under async loads. A tab switch that nukes the subtree during fetch or `$load` guarantees redundant work and nondeterministic UI state.

## Architecture

Make the navigation shell own tabs. Content renders screens. Tabs are not screens.

```swift
public struct JasonetteNavigationView: View {
  @StateObject private var coordinator: JasonetteNavigationCoordinator

  public init(url: URL) {
    _coordinator = StateObject(wrappedValue: .init(entryURL: url))
  }

  public var body: some View {
    JasonetteRootHost(coordinator: coordinator)
      .environment(\.jasonetteNavigator, coordinator.navigator)
      .sheet(item: $coordinator.presentedModal) { modal in
        JasonetteModalHost(state: modal)
      }
  }
}

private struct JasonetteRootHost: View {
  @ObservedObject var coordinator: JasonetteNavigationCoordinator

  var body: some View {
    switch coordinator.mode {
    case .single(let stack):
      JasonetteStackHost(state: stack)

    case .tabs(let shell):
      JasonetteTabShell(shell: shell)
    }
  }
}

private struct JasonetteTabShell: View {
  @ObservedObject var shell: TabShellState

  var body: some View {
    ZStack {
      ForEach(shell.tabs) { tab in
        JasonetteStackHost(state: tab.stackState)
          .opacity(tab.id == shell.selectedTabID ? 1 : 0)
          .allowsHitTesting(tab.id == shell.selectedTabID)
          .accessibilityHidden(tab.id != shell.selectedTabID)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      FooterTabBar(
        items: shell.items,
        selectedTabID: shell.selectedTabID,
        onTap: shell.handleTabTap
      )
    }
  }
}
```

```swift
final class JasonetteNavigationCoordinator: ObservableObject {
  @Published var mode: RootMode
  @Published var presentedModal: ModalState?

  func bootstrapResolvedRoot(_ screen: ScreenState)
  func push(_ route: Route)
  func pop()
  func presentModal(_ route: Route)
  func dismissModal()
  func selectTab(_ tabID: TabID)
  func reselectCurrentTab()
}

final class TabShellState: ObservableObject {
  @Published var selectedTabID: TabID
  @Published var tabs: [TabState]

  var items: [TabBarItemSpec]
  func handleTabTap(_ itemID: TabBarItemID)
}

final class TabState: ObservableObject, Identifiable {
  let id: TabID
  let descriptor: TabDescriptor
  @Published var stackState: StackState
  var hasMountedHost: Bool
}

final class StackState: ObservableObject {
  let root: ScreenState
  @Published var path: [Route]   // Route has UUIDv7 identity
}
```

## Rules

- The tab bar lives in the root shell, outside document content, via `safeAreaInset(edge: .bottom)`.
- Each tab owns its own `StackState`.
- Each stack owns its own root `ScreenState` and push path.
- Switching tabs changes only `selectedTabID`. It does not rebuild stacks.
- Once a tab host is mounted, it stays alive until the shell definition changes.
- `FooterTabBar` is presentational plus tap dispatch only. It does not synthesize navigation requests.

## Bootstrap Strategy

- Start in `.single` mode with one bootstrap stack for the entry URL.
- When the first root document finishes loading, inspect `doc.body.footer.tabs`.
- If there are no tabs, stay in `.single`.
- If there are tabs, promote exactly once into `.tabs`.
- Promotion seeds the matching tab with the already loaded root `ScreenState` so there is no second fetch and no VM reset.
- Other tabs are created lazily from their normalized targets and load only on first selection.
- Tab matching is by canonical target, not by display text.
- If the bootstrap document declares tabs but none of the tab targets matches the bootstrap URL, treat the document as malformed: first tab becomes selected, the bootstrap screen is discarded, and debug builds assert.

## Footer Override Policy

- Only a tab root document may define the shell’s `footer.tabs`.
- Pushed pages do not get to replace, hide, or mutate the shell tab bar.
- `footer.tabs` on pushed pages is ignored and logged in debug.
- Runtime shell changes via `$render` are allowed only when the active tab root document changes its own `footer.tabs`.
- Shell updates diff by canonical target. Existing matching tabs keep their stack state. Removed tabs are dropped. New tabs are added lazily.

## Deep Link and Active Tab Behavior

- Active highlight is driven by `selectedTabID`, full stop.
- A link with `transition: "switch"` inside a tab shell means “select declared tab,” not “replace arbitrary root.”
- If the target matches a declared tab root, select that tab.
- If the target does not match a declared tab root, reject it as invalid `switch` usage and log in debug.
- Deep link to a declared tab root from outside the shell selects that tab without destroying its preserved stack.
- Same-tab reselect pops that tab to root and issues a scroll-to-top signal for the root scroll view.
- Switching away from a tab preserves its pushed stack exactly as-is.

## Modal Semantics

- Modal presentation covers the tab bar. That is correct iOS behavior.
- The underlying tab shell remains alive and unchanged beneath the modal.
- `$close` dismisses the modal.
- `$back` inside a modal pops the modal’s own stack first; at modal root it dismisses the modal.
- `$back` at a tab root is a no-op. It does not switch tabs and does not exit the shell.

## Edge Cases

- `view:web` and `view:app` work as tab roots because `TabDescriptor` stores a full target type, not just a URL.
- Action-only tabs are buttons, not tabs. They execute their action and do not change `selectedTabID`.
- Two tabs with the same canonical target are invalid. Debug builds assert. Release builds keep the first and drop the rest.
- `transition: "switch"` to a pushed detail URL is invalid. Tab switching targets tab roots only.
- If a selected tab is removed by runtime shell update, selection moves to the first surviving tab.
- Scene recreation restores selected tab and lightweight route history through `@SceneStorage`; in-memory tab switches preserve full VM and scroll state without restoration machinery.

## Delete / Rewrite / Keep

- Delete the single global `path: [URL]`.
- Delete `currentRoot`.
- Delete `.id(currentRoot)` from the navigation subtree.
- Delete `NavigationRequest.switchRoot(url)` as the tab-switch primitive.
- Rewrite `JasonetteNavigationView` into a root-shell coordinator host.
- Rewrite `FooterTabItemView` so it never synthesizes `href.transition = "switch"`.
- Rewrite the navigation dispatch layer so content emits semantic actions (`push`, `present`, `selectTab`, `dismissModal`) instead of mutating root identity.
- Keep `JasonetteViewModel`, but remove shell ownership from `handleHref`.
- Keep `StateManager`, but scope it to stable `ScreenState` instances, not ephemeral subtree rebuilds.
- Keep component rendering. Tabs are a shell concern, not a component concern.

## SwiftUI API Choices

- Use `NavigationStack` per tab. That is the correct stack abstraction.
- Use `@StateObject` for the root coordinator and long-lived stack/tab state owners.
- Use `@SceneStorage` only for lightweight restoration keys: selected tab and serialized route descriptors. Never store documents or view models there.
- Use environment values for navigation capabilities (`navigator`, `modalPresenter`, `tabSelection`) instead of threading ad hoc closures through views.
- Use `safeAreaInset(edge: .bottom)` for the persistent tab bar.
- Do not use `TabView` / `.tabItem`. The system tab bar is the wrong fit here because you need action-only items, explicit reselect behavior, shell promotion after bootstrap, and JSON-defined icon/text/badge rendering without surrendering control.

## Public API Surface

- Keep the public surface minimal.
- `JasonetteNavigationView(url:)` stays the sole public container.
- Tabs remain document-driven. Do not expose public tab models just because the internals changed.
- If any navigation API is public today, replace public `switchRoot` semantics with public `selectTab(id:)` only if truly required. Otherwise keep it internal.

## Atomic Migration Order

1. Introduce `Route`, `ScreenState`, `StackState`, and `JasonetteNavigationCoordinator` with tests. No UI wiring yet.
2. Replace URL-only push state with `Route`-based stacks. Remove `path: [URL]` from the public nav container.
3. Add `TabDescriptor`, `TabState`, `TabShellState`, and root-shell promotion logic from the first loaded document.
4. Hoist `footer.tabs` out of `documentBody` and render the persistent `FooterTabBar` from `JasonetteTabShell`.
5. Wire tab selection, active highlight, per-tab preserved stacks, and same-tab reselect pop-to-root.
6. Add modal-over-shell behavior and correct `$back` / `$close` semantics.
7. Ignore descendant `footer.tabs`, support root `$render` tab diffs, and add duplicate-target validation.
8. Delete legacy `switchRoot`, `currentRoot`, `.id(currentRoot)`, and footer-driven root replacement code.
9. Add restoration tests for selected tab and per-tab path, then ship cleanup.

This overhaul gives you actual tab semantics: persistent chrome, preserved per-tab stacks, stable screen state, correct deep linking, and no more subtree nukes on every tab tap.
