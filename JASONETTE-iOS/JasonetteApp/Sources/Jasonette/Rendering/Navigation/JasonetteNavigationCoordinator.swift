import Foundation

/// Top-level navigation mode. Starts `.single`. Promotes to `.tabs` exactly
/// once, after the bootstrap document loads and declares `footer.tabs`.
/// Never demotes.
@MainActor
final class JasonetteNavigationCoordinator: ObservableObject {
    enum Mode {
        /// Single-stack mode. `preloadedDoc` is nil until the first fetch
        /// completes — the root `JasonetteNavigationView` does the fetch.
        case single(rootURL: URL, preloadedDoc: JasonDocument?)

        /// Tabbed mode. Carries the bootstrap document so the matching tab
        /// can render without a second fetch.
        case tabs(shell: TabShellState, bootstrapDoc: JasonDocument, bootstrapURL: URL)
    }

    @Published private(set) var mode: Mode
    let entryURL: URL

    init(entryURL: URL) {
        self.entryURL = entryURL
        self.mode = .single(rootURL: entryURL, preloadedDoc: nil)
    }

    /// Called when the bootstrap document finishes loading. Inspects
    /// `body.footer.tabs`; if present and non-empty, promotes to `.tabs`.
    /// If absent, updates `.single` with the loaded doc so later renders can
    /// read it without re-fetching. Idempotent — second call is ignored.
    func bootstrapDidLoad(doc: JasonDocument) {
        guard case .single = mode else { return }

        let entries = Self.entries(from: doc)
        guard !entries.isEmpty else {
            mode = .single(rootURL: entryURL, preloadedDoc: doc)
            return
        }

        let initial = entries.first { $0.descriptor.selectableURL == entryURL } ?? entries.first!
        if initial.descriptor.selectableURL != entryURL {
            #if DEBUG
            assertionFailure("Bootstrap URL \(entryURL) not in declared tabs — first tab selected, bootstrap doc discarded")
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
                assertionFailure("Duplicate tab target \(key) — first kept, later dropped")
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
    /// for items that have no recognizable target (no href, no url, no
    /// action). The caller filters these out.
    init?(from item: JasonComponent) {
        let label = TabLabelSpec(
            text: item.text,
            iconURL: item.imageURL.flatMap(URL.init(string:)),
            badge: item.badge,
            style: item.style
        )

        if let action = item.action {
            self.init(target: .action(action), label: label)
            return
        }

        let hrefView = item.href?.view
        let urlString = item.href?.url ?? item.url
        guard let s = urlString, let url = URL(string: s) else { return nil }

        switch hrefView {
        case "web":
            self.init(target: .web(url), label: label)
        case "app":
            self.init(target: .app(url), label: label)
        default:
            self.init(target: .document(url), label: label)
        }
    }
}
