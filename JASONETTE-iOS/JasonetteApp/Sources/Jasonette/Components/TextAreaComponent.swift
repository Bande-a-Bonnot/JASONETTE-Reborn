import SwiftUI

struct TextAreaComponent: View {
    static let fallbackPlaceholder = "Enter text"
    static let minimumWidth: CGFloat = 240
    static let minimumHeight: CGFloat = 80
    private static let defaultCornerRadius: CGFloat = 6
    private static let defaultBorderWidth: CGFloat = 1

    let name: String
    let placeholder: String
    let style: JasonStyle?

    @EnvironmentObject private var stateManager: StateManager

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
            textareaBackground

            TextEditor(text: binding)
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
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var textareaBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .allowsHitTesting(false)
    }

    private var cornerRadius: CGFloat {
        style?.cornerRadius?.cgFloat ?? Self.defaultCornerRadius
    }

    private var borderWidth: CGFloat {
        guard style?.borderWidth == nil else { return 0 }
        return Self.defaultBorderWidth
    }

    private var borderColor: Color {
        Color.secondary.opacity(0.35)
    }

    private var fillColor: Color {
        style?.background.flatMap { Color(css: $0) } ?? Self.defaultFillColor
    }

    private static var defaultFillColor: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color.white
        #endif
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
