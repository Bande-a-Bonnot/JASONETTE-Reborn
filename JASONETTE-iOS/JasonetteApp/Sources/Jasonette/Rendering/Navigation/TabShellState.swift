import Foundation
import SwiftUI

/// The entire shell-side state: ordered tabs + which one is selected.
/// Does NOT own paths, stacks, or anything about tab contents.
@MainActor
final class TabShellState: ObservableObject {
    @Published private(set) var selectedTabID: TabID
    let tabs: [TabEntry]

    /// Build a shell from an already-deduped, non-empty list of entries.
    /// Panics on empty input in debug; release clamps to a single unusable
    /// state that the caller should never hit if bootstrap did its job.
    init(tabs: [TabEntry], initialSelection: TabID) {
        precondition(!tabs.isEmpty, "TabShellState requires at least one tab")
        precondition(tabs.contains(where: { $0.id == initialSelection }),
                     "initialSelection must match a tab in the list")
        self.tabs = tabs
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
    @discardableResult
    func switchToURLIfMatches(_ url: URL) -> Bool {
        guard let hit = tabs.first(where: { $0.descriptor.selectableURL == url }) else {
            return false
        }
        selectedTabID = hit.id
        return true
    }
}
