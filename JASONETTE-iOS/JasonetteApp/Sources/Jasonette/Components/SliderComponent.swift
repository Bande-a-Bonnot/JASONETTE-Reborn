import SwiftUI

struct SliderComponent: View {
    let name: String
    let value: Double

    @State private var current: Double = 50

    var body: some View {
        Slider(value: $current, in: 0...100)
            .accessibilityIdentifier(name)
            .onAppear { current = value }
            .onChange(of: value) { current = $0 }
    }
}
