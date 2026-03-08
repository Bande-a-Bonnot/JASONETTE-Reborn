import SwiftUI

struct SliderComponent: View {
    let name: String
    let value: Double

    @EnvironmentObject private var stateManager: StateManager

    var body: some View {
        let binding = stateManager.binding(forKey: name, default: value)
        Slider(value: binding, in: 0...100)
            .accessibilityIdentifier(name)
            .onAppear {
                // Seed initial value if not already set
                if stateManager.local[name] == nil {
                    stateManager.local[name] = value
                }
            }
    }
}
