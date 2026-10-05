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

#if os(iOS)
private struct KeyboardDismissDocumentKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

private struct FocusedKeyboardDismissDocumentKey: FocusedValueKey {
    typealias Value = UUID
}

private extension EnvironmentValues {
    var keyboardDismissDocumentID: UUID? {
        get { self[KeyboardDismissDocumentKey.self] }
        set { self[KeyboardDismissDocumentKey.self] = newValue }
    }
}

private extension FocusedValues {
    var keyboardDismissDocumentID: UUID? {
        get { self[FocusedKeyboardDismissDocumentKey.self] }
        set { self[FocusedKeyboardDismissDocumentKey.self] = newValue }
    }
}

/// Publish ownership only while this input participates in the focused hierarchy.
@MainActor
private struct KeyboardDismissInputModifier: ViewModifier {
    @Environment(\.keyboardDismissDocumentID) private var documentID

    @ViewBuilder
    func body(content: Content) -> some View {
        if let documentID {
            content.focusedValue(\.keyboardDismissDocumentID, documentID)
        } else {
            content
        }
    }
}

/// SwiftUI aggregates input toolbars, so their common document owns the item.
@MainActor
private struct KeyboardDoneToolbarModifier: ViewModifier {
    let documentID: UUID
    @FocusedValue(\.keyboardDismissDocumentID) private var focusedDocumentID

    func body(content: Content) -> some View {
        content
            .environment(\.keyboardDismissDocumentID, documentID)
            .toolbar {
                if focusedDocumentID == documentID {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { KeyboardDismiss.dismiss() }
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
    }
}
#endif

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
    @MainActor
    func keyboardDismissInput() -> some View {
        #if os(iOS)
        self.modifier(KeyboardDismissInputModifier())
        #else
        self
        #endif
    }

    @ViewBuilder
    @MainActor
    func keyboardDoneToolbar(documentID: UUID) -> some View {
        #if os(iOS)
        self.modifier(KeyboardDoneToolbarModifier(documentID: documentID))
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
