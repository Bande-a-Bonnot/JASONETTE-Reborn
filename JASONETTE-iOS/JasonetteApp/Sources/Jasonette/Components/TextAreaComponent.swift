import SwiftUI

struct TextAreaComponent: View {
    let name: String
    let placeholder: String

    @State private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .frame(minHeight: 80)
                .accessibilityIdentifier(name)

            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}
