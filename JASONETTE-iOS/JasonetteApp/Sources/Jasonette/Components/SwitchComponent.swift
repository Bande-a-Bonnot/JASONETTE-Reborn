import SwiftUI

struct SwitchComponent: View {
    let name: String
    let isOn: Bool

    @EnvironmentObject private var stateManager: StateManager

    var body: some View {
        let binding = stateManager.binding(forKey: name, default: isOn)
        Toggle("", isOn: binding)
            .labelsHidden()
            .accessibilityIdentifier(name)
            .onAppear {
                // Seed initial value if not already set
                if stateManager.local[name] == nil {
                    stateManager.local[name] = isOn
                }
            }
    }
}
