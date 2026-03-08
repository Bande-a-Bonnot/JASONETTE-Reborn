import SwiftUI

struct TextAreaComponent: View {
    let name: String
    let placeholder: String

    @EnvironmentObject private var stateManager: StateManager

    var body: some View {
        let binding = stateManager.binding(forKey: name, default: "")
        ZStack(alignment: .topLeading) {
            TextEditor(text: binding)
                .frame(minHeight: 80)
                .accessibilityIdentifier(name)

            if binding.wrappedValue.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}
