import Foundation

/// Top-level navigation mode. Starts `.single`. Promotes to `.tabs` exactly
/// once, after the bootstrap document loads and declares `footer.tabs`.
/// Never demotes.
@MainActor
final class JasonetteNavigationCoordinator: ObservableObject {
    enum Mode {
        /// Single-stack mode. Starts with `preloadedDoc == nil`; when the
        /// bootstrap fetch completes, `bootstrapDidLoad(doc:)` stores the
        /// loaded doc here if the app stays in `.single` (no `footer.tabs`).
        /// That seed is consumed by the root `JasonetteNavigationView` on
        /// first render; subsequent `$reload`/pull-to-refresh refetch from
        /// `rootURL` regardless of the seed.
        case single(rootURL: URL, preloadedDoc: JasonDocument?)

        /// Tabbed mode. Carries the bootstrap document so the matching tab
        /// can render without a second fetch.
        case tabs(shell: TabShellState, bootstrapDoc: JasonDocument, bootstrapURL: URL)
    }

    @Published private(set) var mode: Mode
    let entryURL: URL
    private var didBootstrap = false

    init(entryURL: URL) {
        self.entryURL = entryURL
        self.mode = .single(rootURL: entryURL, preloadedDoc: nil)
    }

    /// Called when the bootstrap document finishes loading. Inspects
    /// `body.footer.tabs`; if present and non-empty, promotes to `.tabs`.
    /// If absent, updates `.single` with the loaded doc so later renders can
    /// read it without re-fetching. One-shot: guarded by `didBootstrap` so a
    /// second call (e.g. after a `$reload` in single mode) never replaces the
    /// preloaded document or re-promotes to `.tabs`.
    func bootstrapDidLoad(doc: JasonDocument) {
        guard !didBootstrap else { return }
        didBootstrap = true
        guard case .single = mode else { return }

        let entries = Self.entries(from: doc)
        guard !entries.isEmpty else {
            mode = .single(rootURL: entryURL, preloadedDoc: doc)
            return
        }

        // Initial selection must land on a document tab — `.web/.app/.action`
        // render nothing, so selecting one would boot into a blank shell.
        let selectable = entries.filter { $0.descriptor.isSelectable }
        guard let initial = selectable.first(where: { $0.descriptor.selectableURL == entryURL })
                ?? selectable.first
        else {
            #if DEBUG
            print("[Jasonette] footer.tabs declared no selectable document target — staying in single mode")
            #endif
            mode = .single(rootURL: entryURL, preloadedDoc: doc)
            return
        }
        if initial.descriptor.selectableURL != entryURL {
            #if DEBUG
            print("[Jasonette] Bootstrap URL \(entryURL) not in declared tabs — first selectable tab used, bootstrap doc discarded")
            #endif
        }

        let shell = TabShellState(tabs: entries, initialSelection: initial.id)
        mode = .tabs(shell: shell, bootstrapDoc: doc, bootstrapURL: entryURL)
    }

    /// Env closure target for `transition: "switch"` hrefs deep inside a tab.
    /// Returns true if a tab was selected; false lets the caller fall back to
    /// `.push` on the current stack.
    func switchToURLIfTab(_ url: URL) -> Bool {
        guard case .tabs(let shell, _, _) = mode else { return false }
        return shell.switchToURLIfMatches(url)
    }

    // MARK: - Bootstrap tab extraction

    /// Convert `doc.body.footer.tabs.items` into deduped `TabEntry`s.
    /// Invalid items (no URL and no action) are dropped. Duplicates by
    /// canonical target key are dropped (first wins); debug-asserts.
    static func entries(from doc: JasonDocument) -> [TabEntry] {
        guard let items = doc.jason.body?.footer?.tabs?.items, !items.isEmpty else {
            return []
        }

        var seen = Set<String>()
        var out: [TabEntry] = []
        out.reserveCapacity(items.count)

        for item in items {
            guard let descriptor = TabDescriptor(from: item) else { continue }
            let key = descriptor.target.canonicalKey
            if seen.contains(key) {
                #if DEBUG
                print("[Jasonette] Duplicate tab target \(key) — first kept, later dropped")
                #endif
                continue
            }
            seen.insert(key)
            out.append(TabEntry(descriptor: descriptor))
        }

        return out
    }
}

// MARK: - JasonComponent → TabDescriptor

extension TabDescriptor {
    /// Convert a footer-tabs `JasonComponent` into a descriptor. Returns nil
    /// for items that have no recognizable target or whose URL scheme isn't
    /// allowed for that target kind — same scheme allowlist `handleHref` uses.
    /// The caller filters these out.
    ///
    /// Icon resolution reads `item.image` directly. `item.imageURL` falls
    /// back to `item.url`, which for tabs is the target document URL — that
    /// would try to render JSON as an image.
    init?(from item: JasonComponent) {
        let label = TabLabelSpec(
            text: item.text,
            iconURL: item.image.flatMap(URL.init(string:)),
            badge: item.badge,
            style: item.style
        )

        // Action-only tabs are not yet dispatched from the shell — tapping
        // them would be a silent no-op in release. Reject at construction
        // until action dispatch is plumbed through (see todos/026).
        if item.action != nil, item.href == nil, item.url == nil {
            return nil
        }

        let hrefView = item.href?.view
        let urlString = item.href?.url ?? item.url
        guard let s = urlString, let url = URL(string: s) else { return nil }
        guard let scheme = url.scheme?.lowercased() else { return nil }

        // Same allowlist as JasonetteViewModel.handleHref so a tab can't open
        // a URL that a programmatic href would have been rejected for.
        switch hrefView {
        case "web":
            guard DocumentLoader.allowedSchemes.contains(scheme) else { return nil }
            self.init(target: .web(url), label: label)
        case "app":
            guard DocumentLoader.appSchemes.contains(scheme) else { return nil }
            self.init(target: .app(url), label: label)
        default:
            guard DocumentLoader.allowedSchemes.contains(scheme) else { return nil }
            self.init(target: .document(url), label: label)
        }
    }
}
