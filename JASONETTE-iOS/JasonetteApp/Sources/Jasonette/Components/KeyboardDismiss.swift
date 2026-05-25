import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Shared keyboard dismissal hook for text inputs.
///
/// SwiftUI does not expose a platform-neutral imperative dismiss API for all
/// input variants we render (TextField, SecureField, TextEditor, footer input),
/// so iOS routes through UIKit's responder chain. Non-iOS platforms compile as
/// a no-op because they do not use the software keyboard UX this fixes.
enum KeyboardDismiss {
    static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

extension View {
    @ViewBuilder
    func dismissKeyboardOnSubmit() -> some View {
        #if os(iOS)
        self
            .submitLabel(.done)
            .onSubmit { KeyboardDismiss.dismiss() }
        #else
        self
        #endif
    }

    @ViewBuilder
    func keyboardDoneToolbar() -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { KeyboardDismiss.dismiss() }
            }
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func dismissKeyboardOnScroll() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    @ViewBuilder
    func dismissKeyboardOnTap() -> some View {
        #if os(iOS)
        self
            .contentShape(Rectangle())
            .onTapGesture { KeyboardDismiss.dismiss() }
        #else
        self
        #endif
    }
}
