import SwiftUI

struct TextAreaComponent: View {
    static let fallbackPlaceholder = "Enter text"
    static let minimumWidth: CGFloat = 240
    static let minimumHeight: CGFloat = 80

    let name: String
    let placeholder: String
    let style: JasonStyle?

    @EnvironmentObject private var stateManager: StateManager
    @Environment(\.rendererAppearance) private var appearance
    @Environment(\.colorScheme) private var systemScheme

    static func visiblePlaceholder(_ placeholder: String) -> String {
        let trimmed = placeholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackPlaceholder : placeholder
    }

    static func accessibilityLabel(name: String, placeholder: String) -> String {
        let visible = visiblePlaceholder(placeholder)
        if visible != fallbackPlaceholder { return visible }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallbackPlaceholder : "\(trimmedName) text area"
    }

    var body: some View {
        let binding = stateManager.binding(forKey: name, default: "")
        ZStack(alignment: .topLeading) {
            RendererInputSurface(appearance: inputAppearance, style: style)

            TextEditor(text: binding)
                .foregroundColor(inputAppearance.foreground.color)
                .scrollContentBackgroundHidden()
                .keyboardDoneToolbar()
                .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .accessibilityIdentifier(name)
                .accessibilityLabel(Self.accessibilityLabel(name: name, placeholder: placeholder))
                .accessibilityHint("Double tap to edit text")

            if binding.wrappedValue.isEmpty {
                Text(Self.visiblePlaceholder(placeholder))
                    .foregroundColor(inputAppearance.placeholder.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
        .contentShape(RoundedRectangle(cornerRadius: style?.cornerRadius?.cgFloat ?? RendererInputSurface.defaultCornerRadius))
    }

    private var inputAppearance: RendererInputAppearance {
        (appearance ?? RendererAppearance.document(body: nil, systemScheme: systemScheme)).input(style: style)
    }
}

private extension View {
    @ViewBuilder
    func scrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, visionOS 1.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
