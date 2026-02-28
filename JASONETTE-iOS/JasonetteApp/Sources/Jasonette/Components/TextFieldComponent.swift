import SwiftUI

struct TextFieldComponent: View {
    let name: String
    let placeholder: String
    let keyboard: String?

    @State private var text: String = ""

    var body: some View {
        textField
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier(name)
    }

    @ViewBuilder
    private var textField: some View {
        #if os(iOS)
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
        #else
        TextField(placeholder, text: $text)
        #endif
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
