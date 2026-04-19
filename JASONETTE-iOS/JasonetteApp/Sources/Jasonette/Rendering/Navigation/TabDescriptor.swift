import Foundation

/// A single declared tab: what it targets, and how it renders in the bar.
/// Not Hashable — `JasonAction`/`JasonStyle` carry non-Hashable payloads.
/// Deduplication keys off `target.canonicalKey`, not the whole descriptor.
struct TabDescriptor: Sendable {
    let target: Target
    let label: TabLabelSpec

    enum Target: Sendable {
        /// Normal tab: selecting it switches the shell to this scope.
        case document(URL)
        /// Safari on iOS, openURL elsewhere. Tap does NOT change selection.
        case web(URL)
        /// External app open. Tap does NOT change selection.
        case app(URL)
        // `.action` (fire a JSON action on tap, selection unchanged) will be
        // added back when action dispatch is plumbed through — tracked in
        // `todos/026-ready-p2-action-tab-dispatch.md`. Until then, action-only
        // footer items are rejected at `TabDescriptor(from:)` construction and
        // the shell has no unreachable no-op branch to ship by accident.

        /// String form used for duplicate detection at bootstrap.
        var canonicalKey: String {
            switch self {
            case .document(let url): return "doc:\(url.absoluteString)"
            case .web(let url):      return "web:\(url.absoluteString)"
            case .app(let url):      return "app:\(url.absoluteString)"
            }
        }
    }

    /// True for targets that, on tap, switch the shell to this tab.
    var isSelectable: Bool {
        if case .document = target { return true }
        return false
    }

    /// The URL this tab matches for transition:"switch" routing. Nil for
    /// non-selectable (action/web/app) tabs.
    var selectableURL: URL? {
        if case .document(let url) = target { return url }
        return nil
    }
}

/// Presentational spec for the tab bar cell. Never carries navigation intent.
struct TabLabelSpec: Sendable {
    let text: String?
    let iconURL: URL?
    let badge: String?
    let style: JasonStyle?
}
