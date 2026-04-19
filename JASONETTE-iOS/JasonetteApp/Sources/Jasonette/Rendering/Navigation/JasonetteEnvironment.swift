import SwiftUI

/// True when the current view subtree is hosted inside a `JasonetteTabShell`.
/// Read by `JasonetteView` to suppress its own `footer.tabs` rendering —
/// the tab bar is an app-shell concern and must not be re-declared by
/// pushed pages or secondary documents.
private struct JasonetteIsInsideTabShellKey: EnvironmentKey {
    static let defaultValue = false
}

/// Ask the enclosing tab shell to select the tab whose target URL matches.
/// Returns true on hit, false on miss. Default (no shell) always returns
/// false, so callers can unconditionally try and fall back to `.push`.
/// Callers that mutate main-actor state must be invoked from MainActor
/// context — which the single call site (`JasonetteNavigationView.dispatch`)
/// already is.
private struct JasonetteSwitchTabKey: EnvironmentKey {
    static let defaultValue: (URL) -> Bool = { _ in false }
}

extension EnvironmentValues {
    var jasonetteIsInsideTabShell: Bool {
        get { self[JasonetteIsInsideTabShellKey.self] }
        set { self[JasonetteIsInsideTabShellKey.self] = newValue }
    }

    var jasonetteSwitchTab: (URL) -> Bool {
        get { self[JasonetteSwitchTabKey.self] }
        set { self[JasonetteSwitchTabKey.self] = newValue }
    }
}
