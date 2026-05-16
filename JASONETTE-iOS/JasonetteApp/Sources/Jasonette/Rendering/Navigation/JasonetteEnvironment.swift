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

/// Identifies which tab scope the current Jasonette view belongs to. The shell
/// installs this per mounted `JasonetteNavigationView`; views use it when
/// registering their action dispatcher as the active handler for that tab.
private struct JasonetteCurrentTabIDKey: EnvironmentKey {
    static let defaultValue: TabID? = nil
}

/// Registers the active action handler for a tab. The default is a no-op so
/// standalone `JasonetteNavigationView`/`JasonetteView` instances do not need
/// shell wiring.
private struct JasonetteRegisterTabActionHandlerKey: EnvironmentKey {
    static let defaultValue: (TabID, @escaping (JasonAction) -> Void) -> Void = { _, _ in }
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

    var jasonetteCurrentTabID: TabID? {
        get { self[JasonetteCurrentTabIDKey.self] }
        set { self[JasonetteCurrentTabIDKey.self] = newValue }
    }

    var jasonetteRegisterTabActionHandler: (TabID, @escaping (JasonAction) -> Void) -> Void {
        get { self[JasonetteRegisterTabActionHandlerKey.self] }
        set { self[JasonetteRegisterTabActionHandlerKey.self] = newValue }
    }
}

@MainActor
final class TabActionRegistry: ObservableObject {
    private var handlers: [TabID: (JasonAction) -> Void] = [:]

    func register(_ tabID: TabID, handler: @escaping (JasonAction) -> Void) {
        handlers[tabID] = handler
    }

    @discardableResult
    func dispatch(_ action: JasonAction, selectedTabID: TabID) -> Bool {
        guard let handler = handlers[selectedTabID] else { return false }
        handler(action)
        return true
    }
}
