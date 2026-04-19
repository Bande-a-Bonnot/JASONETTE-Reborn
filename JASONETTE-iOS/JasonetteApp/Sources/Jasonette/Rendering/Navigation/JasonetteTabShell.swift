import SwiftUI

/// Hosts N tab scopes. Each scope is an opaque `JasonetteNavigationView` —
/// the shell does not know or care how it navigates internally. Tab switches
/// are shell-local (toggle opacity, flip `selectedTabID`); navigation within
/// a tab belongs to that tab's nav view.
@MainActor
struct JasonetteTabShell: View {
    @ObservedObject var shell: TabShellState
    let bootstrapDoc: JasonDocument
    let bootstrapURL: URL
    @Environment(\.openURL) private var openURL

    /// Canonical key of the tab the user last had selected when the scene was
    /// active. Takes precedence over the coordinator's entry-URL match when
    /// the key still resolves to a selectable tab. Deep links arriving after
    /// restore still win because they mutate `selectedTabID` directly.
    @SceneStorage("jasonette.selectedTab") private var storedKey: String = ""

    var body: some View {
        ZStack {
            ForEach(shell.tabs) { tab in
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
        .onAppear { shell.selectByCanonicalKey(storedKey) }
        .onChange(of: shell.selectedTabID) { _ in
            storedKey = shell.selectedCanonicalKey
        }
    }

    @ViewBuilder
    private func content(for tab: TabEntry) -> some View {
        switch tab.descriptor.target {
        case .document(let url):
            JasonetteNavigationView(
                url: url,
                preloadedDoc: url == bootstrapURL ? bootstrapDoc : nil
            )
        case .web, .app, .action:
            // Non-selectable tabs have no mounted scope. The tap is handled
            // in `handleTap` and does not change selection, so rendering
            // Color.clear here is fine — the tab is visible in the bar only.
            Color.clear
        }
    }

    private func handleTap(_ tab: TabEntry) {
        switch tab.descriptor.target {
        case .document:
            shell.select(tab.id)
        case .web(let url), .app(let url):
            openURL(url)
        case .action:
            #if DEBUG
            print("[Jasonette] Tab action dispatch not yet implemented")
            #endif
        }
    }
}
