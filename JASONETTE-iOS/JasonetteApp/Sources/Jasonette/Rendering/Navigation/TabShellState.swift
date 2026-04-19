import Foundation
import SwiftUI

/// The entire shell-side state: ordered tabs + which one is selected.
/// Does NOT own paths, stacks, or anything about tab contents.
@MainActor
final class TabShellState: ObservableObject {
    @Published private(set) var selectedTabID: TabID
    let tabs: [TabEntry]
    /// Precomputed subset of `tabs` whose descriptors are `.document` (i.e.
    /// have a mounted scope). The shell's ZStack iterates this instead of
    /// filtering on every render. Stable for the lifetime of the state.
    let selectableTabs: [TabEntry]

    /// Build a shell from an already-deduped, non-empty list of entries.
    /// Traps (both debug and release, via `precondition`) on empty input or
    /// on an initial selection that doesn't match a selectable tab. The
    /// coordinator filters to selectable tabs before calling this — any trap
    /// is a bug in the bootstrap path, not something callers can recover from.
    init(tabs: [TabEntry], initialSelection: TabID) {
        precondition(!tabs.isEmpty, "TabShellState requires at least one tab")
        precondition(
            tabs.contains(where: { $0.id == initialSelection && $0.descriptor.isSelectable }),
            "initialSelection must match a selectable tab"
        )
        self.tabs = tabs
        self.selectableTabs = tabs.filter { $0.descriptor.isSelectable }
        self.selectedTabID = initialSelection
    }

    /// Programmatic selection by ID. Non-selectable tabs (web/app/action) are
    /// rejected. Same-ID reselect is a no-op at this layer — the shell view
    /// detects same-ID taps and emits the scroll-top signal (phase 2).
    func select(_ id: TabID) {
        guard let entry = tabs.first(where: { $0.id == id }), entry.descriptor.isSelectable else {
            return
        }
        selectedTabID = id
    }

    /// Match a URL against the tabs' selectable targets. If one matches,
    /// select it and return true. Returns false for no match — caller should
    /// fall through to `.push`.
    ///
    /// Comparison uses `.standardized` on both sides so `transition: "switch"`
    /// hrefs that differ only in `.`/`..` path segments still resolve to the
    /// same tab the coordinator picked at bootstrap. Trailing slashes and
    /// host casing are deliberately not normalized — that matches the
    /// `canonicalKey` invariant.
    @discardableResult
    func switchToURLIfMatches(_ url: URL) -> Bool {
        let target = url.standardized
        guard let hit = tabs.first(where: { $0.descriptor.selectableURL?.standardized == target }) else {
            return false
        }
        selectedTabID = hit.id
        return true
    }

    /// SceneStorage restore path. If the stored canonical key still matches a
    /// currently-selectable tab, flip selection and return true. Returns
    /// false when the stored key is empty, unknown (tab bar changed between
    /// launches), or points at a non-selectable tab.
    @discardableResult
    func selectByCanonicalKey(_ key: String) -> Bool {
        guard !key.isEmpty,
              let hit = tabs.first(where: { $0.descriptor.target.canonicalKey == key }),
              hit.descriptor.isSelectable
        else { return false }
        selectedTabID = hit.id
        return true
    }

    /// Canonical key of the currently-selected tab. Used to persist selection
    /// across launches via `@SceneStorage`.
    var selectedCanonicalKey: String {
        tabs.first(where: { $0.id == selectedTabID })?.descriptor.target.canonicalKey ?? ""
    }
}
