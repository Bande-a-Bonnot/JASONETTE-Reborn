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

    @EnvironmentObject private var stateManager: StateManager

    static func fieldKind(componentType: String?, style: JasonStyle?) -> FieldKind {
        componentType == "secure" || style?.isSecureTextEntry == true ? .secure : .plain
    }

    var body: some View {
        textField
            .textFieldStyle(.roundedBorder)
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
        switch kind {
        case .plain:
            #if os(iOS)
            TextField(placeholder, text: binding)
                .keyboardType(keyboardType)
            #else
            TextField(placeholder, text: binding)
            #endif
        case .secure:
            #if os(iOS)
            SecureField(placeholder, text: binding)
                .textContentType(.password)
                .keyboardType(keyboardType)
            #else
            SecureField(placeholder, text: binding)
            #endif
        }
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
