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
        /// Fire a JSON action on tap. Selection does not change; the shell
        /// forwards the action to the currently-selected tab's active VM.
        case action(JasonAction)

        /// String form used for duplicate detection at bootstrap and for
        /// `@SceneStorage` restoration. Built from `standardized.absoluteString`
        /// so `https://host/a/../b` dedupes against `https://host/b`. Trailing
        /// slashes and host casing are NOT normalized — `URL.standardized`
        /// only resolves `.` / `..` path segments. Authors declaring two
        /// cosmetically-different tab URLs (e.g. `/home` vs `/home/`) will
        /// get two distinct tabs; that matches how `URL` equality already
        /// behaves everywhere else in Jasonette.
        var canonicalKey: String {
            switch self {
            case .document(let url): return "doc:\(url.standardized.absoluteString)"
            case .web(let url):      return "web:\(url.standardized.absoluteString)"
            case .app(let url):      return "app:\(url.standardized.absoluteString)"
            case .action(let action): return "action:\(action.stableHash)"
            }
        }
    }

    /// True for targets that, on tap, switch the shell to this tab.
    var isSelectable: Bool {
        if case .document = target { return true }
        return false
    }

    /// The URL this tab matches for transition:"switch" routing. Nil for
    /// non-selectable (web/app/action) tabs.
    var selectableURL: URL? {
        if case .document(let url) = target { return url }
        return nil
    }
}

/// Presentational spec for the tab bar cell. Never carries navigation intent.
struct TabLabelSpec: Sendable {
    let text: String?
    let iconURL: URL?
    let systemImageName: String?
    let badge: String?
    let style: JasonStyle?

    init(text: String?, iconURL: URL?, systemImageName: String? = nil, badge: String?, style: JasonStyle?) {
        self.text = text
        self.iconURL = iconURL
        self.systemImageName = systemImageName
        self.badge = badge
        self.style = style
    }
}
