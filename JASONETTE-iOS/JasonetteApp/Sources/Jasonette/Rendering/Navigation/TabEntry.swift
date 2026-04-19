import Foundation

/// One entry in the tab shell's list. Holds identity + descriptor ONLY.
/// There is no per-tab navigation state here by design — each tab's content
/// (a `JasonetteNavigationView`) owns its own path, modal slot, and VM. The
/// shell never peers inside.
struct TabEntry: Identifiable, Sendable {
    let id: TabID
    let descriptor: TabDescriptor

    init(descriptor: TabDescriptor, id: TabID = TabID()) {
        self.descriptor = descriptor
        self.id = id
    }
}
