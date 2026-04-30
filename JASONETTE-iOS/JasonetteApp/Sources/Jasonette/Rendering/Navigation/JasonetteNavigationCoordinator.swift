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
        case single(rootURL: URL, preloadedDoc: JasonDocument?, preloadedDocumentURL: URL?)

        /// Tabbed mode. Carries the bootstrap document so the matching tab
        /// can render without a second fetch.
        case tabs(shell: TabShellState, bootstrapDoc: JasonDocument, bootstrapURL: URL)
    }

    @Published private(set) var mode: Mode
    let entryURL: URL
    /// Final loaded document URL used as the relative-reference base while
    /// extracting shell-mounted tab descriptors from the bootstrap document.
    /// This is distinct from the shell's `bootstrapURL`, which is only a
    /// preload identity key and may intentionally be the original entry URL
    /// when authors declare absolute pre-redirect tab URLs. Broader body/action
    /// base-URL plumbing remains tracked by todos/034.
    private(set) var bootstrapDocumentURL: URL?
    private var didBootstrap = false

    init(entryURL: URL) {
        self.entryURL = entryURL
        self.mode = .single(rootURL: entryURL, preloadedDoc: nil, preloadedDocumentURL: nil)
    }

    /// Called when the bootstrap document finishes loading. Inspects
    /// `body.footer.tabs`; if present and non-empty, promotes to `.tabs`.
    /// If absent, updates `.single` with the loaded doc so later renders can
    /// read it without re-fetching. One-shot: guarded by `didBootstrap` so a
    /// second call (e.g. after a `$reload` in single mode) never replaces the
    /// preloaded document or re-promotes to `.tabs`.
    func bootstrapDidLoad(doc: JasonDocument, documentURL: URL? = nil) {
        guard !didBootstrap else { return }
        didBootstrap = true
        guard case .single = mode else { return }

        let bootstrapURL = documentURL ?? entryURL
        bootstrapDocumentURL = bootstrapURL
        let entries = Self.entries(from: doc, baseURL: bootstrapURL)
        guard !entries.isEmpty else {
            mode = .single(rootURL: entryURL, preloadedDoc: doc, preloadedDocumentURL: bootstrapURL)
            return
        }

        // Initial selection must land on a document tab — `.web` and `.app`
        // render nothing, so selecting one would boot into a blank shell.
        // Match by `.standardized` to absorb `.`/`..` path differences so
        // this stays in lockstep with `TabDescriptor.Target.canonicalKey`
        // and `JasonetteTabShell`'s preload-doc hand-off.
        let selectable = entries.filter { $0.descriptor.isSelectable }
        let bootstrapStd = bootstrapURL.standardized
        let entryStd = entryURL.standardized
        func matches(_ url: URL?, _ candidate: URL) -> Bool {
            url?.standardized == candidate.standardized
        }
        func matchesBootstrapAlias(_ url: URL?) -> Bool {
            matches(url, bootstrapStd) || matches(url, entryStd)
        }
        guard let initial = selectable.first(where: { matches($0.descriptor.selectableURL, bootstrapStd) })
                ?? selectable.first(where: { matches($0.descriptor.selectableURL, entryStd) })
                ?? selectable.first
        else {
            #if DEBUG
            print("[Jasonette] footer.tabs declared no selectable document target — staying in single mode")
            #endif
            mode = .single(rootURL: entryURL, preloadedDoc: doc, preloadedDocumentURL: bootstrapURL)
            return
        }
        let matchedBootstrapAlias = matchesBootstrapAlias(initial.descriptor.selectableURL)
        if !matchedBootstrapAlias {
            #if DEBUG
            print("[Jasonette] Bootstrap URL \(bootstrapURL) not in declared tabs — first selectable tab used, bootstrap doc discarded")
            #endif
        }

        // On a miss, keep `bootstrapURL` as the preload identity key. No
        // selectable tab matched it (checked above), so `JasonetteTabShell`
        // will not hand `bootstrapDoc` to the fallback first tab and that tab
        // will fetch normally.
        let preloadURL = matchedBootstrapAlias ? (initial.descriptor.selectableURL ?? bootstrapURL) : bootstrapURL
        let shell = TabShellState(tabs: entries, initialSelection: initial.id)
        mode = .tabs(shell: shell, bootstrapDoc: doc, bootstrapURL: preloadURL)
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
    static func entries(from doc: JasonDocument, baseURL: URL) -> [TabEntry] {
        guard let items = doc.jason.body?.footer?.tabs?.items, !items.isEmpty else {
            return []
        }

        var seen = Set<String>()
        var out: [TabEntry] = []
        out.reserveCapacity(items.count)

        for item in items {
            guard let descriptor = TabDescriptor(from: item, baseURL: baseURL) else { continue }
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
    /// Icon resolution reads `item.image` directly and accepts only http(s)
    /// image URLs. `item.imageURL` falls back to `item.url`, which for tabs is
    /// the target document URL — that would try to render JSON as an image.
    init?(from item: JasonComponent, baseURL: URL? = nil) {
        let iconURL = item.image
            .flatMap { JasonURL.resolve($0, against: baseURL) }
            .flatMap { url -> URL? in
                guard let scheme = url.scheme?.lowercased(),
                      DocumentLoader.allowedSchemes.contains(scheme) else { return nil }
                return url
            }
        let label = TabLabelSpec(
            text: item.text,
            iconURL: iconURL,
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
        guard let s = urlString, let url = JasonURL.resolve(s, against: baseURL) else { return nil }
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
