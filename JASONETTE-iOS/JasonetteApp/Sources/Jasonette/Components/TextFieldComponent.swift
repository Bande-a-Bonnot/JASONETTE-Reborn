import SwiftUI

struct TextFieldComponent: View {
    enum FieldKind: Equatable {
        case plain
        case secure
    }

    let name: String
    let placeholder: String
    let keyboard: String?
    let initialValue: String?
    let kind: FieldKind
    var style: JasonStyle? = nil

    @EnvironmentObject private var stateManager: StateManager
    @Environment(\.rendererAppearance) private var appearance
    @Environment(\.colorScheme) private var systemScheme

    static func fieldKind(componentType: String?, style: JasonStyle?) -> FieldKind {
        componentType == "secure" || style?.isSecureTextEntry == true ? .secure : .plain
    }

    var body: some View {
        textField
            .dismissKeyboardOnSubmit()
            .keyboardDoneToolbar()
            .modifier(RendererTextInputModifier(style: style))
            .accessibilityIdentifier(name)
            .onAppear {
                if let initialValue, stateManager.local[name] == nil {
                    stateManager.local[name] = initialValue
                }
            }
    }

    @ViewBuilder
    private var textField: some View {
        let binding = stateManager.binding(forKey: name, default: "")
        let prompt = Text(placeholder).foregroundColor(inputAppearance.placeholder.color)
        switch kind {
        case .plain:
            #if os(iOS)
            TextField(placeholder, text: binding, prompt: prompt)
                .keyboardType(keyboardType)
            #else
            TextField(placeholder, text: binding, prompt: prompt)
            #endif
        case .secure:
            #if os(iOS)
            SecureField(placeholder, text: binding, prompt: prompt)
                .textContentType(.password)
                .keyboardType(keyboardType)
            #else
            SecureField(placeholder, text: binding, prompt: prompt)
            #endif
        }
    }

    private var inputAppearance: RendererInputAppearance {
        (appearance ?? RendererAppearance.document(body: nil, systemScheme: systemScheme)).input(style: style)
    }

    #if os(iOS)
    private var keyboardType: UIKeyboardType {
        switch keyboard {
        case "number", "numeric":
            return .numberPad
        case "decimal":
            return .decimalPad
        case "phone":
            return .phonePad
        case "email":
            return .emailAddress
        case "url":
            return .URL
        default:
            return .default
        }
    }
    #endif
}
