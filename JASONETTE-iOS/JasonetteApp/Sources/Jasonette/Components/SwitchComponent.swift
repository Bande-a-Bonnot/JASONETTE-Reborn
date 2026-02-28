import SwiftUI

struct SwitchComponent: View {
    let name: String
    let isOn: Bool

    @State private var current: Bool = false

    var body: some View {
        Toggle("", isOn: $current)
            .labelsHidden()
            .accessibilityIdentifier(name)
            .onAppear { current = isOn }
            .onChange(of: isOn) { current = $0 }
    }
}
