import Foundation

/// Stable identity for a tab. Never derived from the tab's URL — two tabs
/// can legitimately point at the same document, and URLs can change at
/// runtime without invalidating tab identity.
public struct TabID: Hashable, Sendable {
    let value: UUID

    init() { self.value = UUIDv7.generate() }
    init(_ value: UUID) { self.value = value }
}
