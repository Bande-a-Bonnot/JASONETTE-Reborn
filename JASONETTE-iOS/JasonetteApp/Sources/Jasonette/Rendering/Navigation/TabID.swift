import Foundation

/// Stable identity for a tab. Never derived from the tab's URL — two tabs
/// can legitimately point at the same document, and URLs can change at
/// runtime without invalidating tab identity.
public struct TabID: Hashable, Sendable {
    let value: UUID

    init() { self.value = UUIDv7.generate() }

    /// Accepts an existing UUIDv7. Traps in debug on a non-v7 UUID so accidents
    /// (e.g. passing `UUID()`) surface during development. Release builds
    /// accept any UUID — the invariant is a development-time guardrail, not a
    /// security boundary.
    init(_ value: UUID) {
        assert((value.uuid.6 & 0xF0) == 0x70, "TabID requires a UUIDv7 value — got \(value)")
        self.value = value
    }
}
