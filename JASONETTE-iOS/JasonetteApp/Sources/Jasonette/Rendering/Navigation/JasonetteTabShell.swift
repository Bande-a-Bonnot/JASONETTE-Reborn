import SwiftUI

struct TabContentStackOrder {
    static func selectedLast(from tabs: [TabEntry], selectedID: TabID) -> [TabEntry] {
        guard let selectedIndex = tabs.firstIndex(where: { $0.id == selectedID }) else {
            return tabs
        }
        var orderedTabs = tabs
        let selected = orderedTabs.remove(at: selectedIndex)
        orderedTabs.append(selected)
        return orderedTabs
    }
}

/// Hosts N tab scopes. Each scope is an opaque `JasonetteNavigationView` —
/// the shell does not know or care how it navigates internally. Tab switches
/// are shell-local (toggle opacity, flip `selectedTabID`); navigation within
/// a tab belongs to that tab's nav view.
@MainActor
struct JasonetteTabShell: View {
    @ObservedObject var shell: TabShellState
    let bootstrapDoc: JasonDocument
    let bootstrapURL: URL
    let bootstrapDocumentURL: URL?
    @Environment(\.openURL) private var openURL
    @State private var safariURL: IdentifiableURL?

    /// Canonical key of the tab the user last had selected when the scene was
    /// last active. Precedence: deep link > stored key > entry URL > first
    /// tab. The coordinator has already applied "deep link (entry URL match)
    /// or first selectable," so onAppear only overrides its choice when the
    /// coordinator fell back to the first tab (i.e., entry URL did not match
    /// any selectable tab).
    @SceneStorage("jasonette.selectedTab") private var storedKey: String = ""

    /// Tabs whose content has been mounted at least once. Hidden tabs stay
    /// as `Color.clear` until first selection so they don't eagerly fetch,
    /// run `$load`, or hold timers. Once mounted, a tab stays mounted for
    /// the rest of the scene's lifetime — that's what preserves its VM,
    /// nav path, scroll position, and modal slot across later re-selections.
    @State private var mounted: Set<TabID> = []
    @StateObject private var actionRegistry = TabActionRegistry()

    var body: some View {
        ZStack {
            // Only document tabs produce content; web/app/action tabs live in
            // the bar and are handled on tap, never rendered in the stack.
            // `selectableTabs` is precomputed on `TabShellState`, not filtered
            // per render. Keep the selected NavigationStack last in the
            // ZStack so hidden sibling stacks cannot win SwiftUI navigation
            // title/toolbar propagation over the visible tab.
            ForEach(TabContentStackOrder.selectedLast(
                from: shell.selectableTabs,
                selectedID: shell.selectedTabID
            )) { tab in
                let selected = tab.id == shell.selectedTabID
                content(for: tab)
                    .opacity(selected ? 1 : 0)
                    .allowsHitTesting(selected)
                    .accessibilityHidden(!selected)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTabBar(
                tabs: shell.tabs,
                selectedTabID: shell.selectedTabID,
                onTap: handleTap
            )
        }
        .environment(\.jasonetteIsInsideTabShell, true)
        .environment(\.jasonetteSwitchTab) { url in
            shell.switchToURLIfMatches(url)
        }
        .environment(\.jasonetteRegisterTabActionHandler) { tabID, handler in
            actionRegistry.register(tabID, handler: handler)
        }
        #if os(iOS)
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        #endif
        .onAppear {
            // Precedence: stored key > coordinator's pick (entry URL match,
            // else first selectable). A non-empty stored key always wins when
            // it still resolves to a selectable tab — otherwise the shell
            // would always re-open on the entry tab in the common case where
            // the entry URL is itself a tab, and users would never see their
            // last selection restored. `selectByCanonicalKey` is a no-op on
            // miss, so an unknown/stale key leaves the coordinator's pick
            // intact.
            shell.selectByCanonicalKey(storedKey)
            // Flush current selection's key back so a stale storedKey (points
            // at a tab that no longer exists) doesn't linger across launches.
            storedKey = shell.selectedCanonicalKey
            mounted.insert(shell.selectedTabID)
        }
        .onChange(of: shell.selectedTabID) { _, newID in
            storedKey = shell.selectedCanonicalKey
            mounted.insert(newID)
        }
    }

    /// Only called for selectable tabs (filtered in `body`). The default
    /// branch covers non-selectable descriptors that should never reach here
    /// — if one does, the filter and `TabDescriptor.isSelectable` are out of
    /// sync, which is a caller bug, not data.
    @ViewBuilder
    private func content(for tab: TabEntry) -> some View {
        switch tab.descriptor.target {
        case .document(let url):
            if mounted.contains(tab.id) {
                // Preloaded-doc hand-off is a fetch optimization, not a
                // correctness invariant — on miss, `JasonetteView` just
                // re-fetches from `url`. `.standardized` resolves `.`/`..`
                // path segments so `/a/../b` matches `/b`, which keeps this
                // in lockstep with `TabDescriptor.Target.canonicalKey` and
                // `TabShellState.switchToURLIfMatches`. Trailing slashes,
                // host casing, and query-order divergence still miss; cost
                // is one extra fetch, not a broken shell.
                let shouldPreload = url.standardized == bootstrapURL.standardized
                JasonetteNavigationView(
                    url: url,
                    preloadedDoc: shouldPreload ? bootstrapDoc : nil,
                    preloadedDocumentURL: shouldPreload ? bootstrapDocumentURL : nil
                )
                .environment(\.jasonetteCurrentTabID, tab.id)
            } else {
                Color.clear
            }
        default:
            Color.clear
        }
    }

    private func handleTap(_ tab: TabEntry) {
        switch tab.descriptor.target {
        case .document:
            shell.select(tab.id)
        case .web(let url):
            // Parity with JasonetteNavigationView.dispatch(.web): in-app
            // Safari on iOS, system browser elsewhere.
            #if os(iOS)
            safariURL = IdentifiableURL(url)
            #else
            openURL(url)
            #endif
        case .app(let url):
            openURL(url)
        case .action(let action):
            if shell.switchIfActionHrefTargetsTab(action, baseURL: bootstrapDocumentURL) {
                return
            }
            if !actionRegistry.dispatch(action, selectedTabID: shell.selectedTabID) {
                #if DEBUG
                print("[Jasonette] Action tab tapped before selected tab action handler registered")
                #endif
            }
        }
    }
}
