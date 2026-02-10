import SwiftUI
import UIKit

struct FormSheetView<Content: View>: View {
    let title: String
    let confirmTitle: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    let isConfirmDisabled: Bool
    let autoFocusFirstTextField: Bool
    @ViewBuilder var content: Content

    init(
        title: String,
        confirmTitle: String,
        isConfirmDisabled: Bool = false,
        autoFocusFirstTextField: Bool = true,
        confirmAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.autoFocusFirstTextField = autoFocusFirstTextField
        self.confirmAction = confirmAction
        self.cancelAction = cancelAction
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .overlay {
                    if autoFocusFirstTextField {
                        AutoFocusTextFieldProbe()
                            .frame(width: 0, height: 0)
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена",systemImage: "xmark", action: cancelAction)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle, systemImage: "checkmark",action: confirmTapped)
                            .disabled(isConfirmDisabled)
                    }
                }
        }
    }

    private func confirmTapped() {
        guard !isConfirmDisabled else { return }
        confirmAction()
    }
}

private struct AutoFocusTextFieldProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard !context.coordinator.didFocus else { return }
        guard let rootView = uiView.nearestRootInHierarchy else { return }
        guard rootView.firstResponderDescendant == nil else {
            context.coordinator.didFocus = true
            return
        }

        DispatchQueue.main.async {
            guard !context.coordinator.didFocus else { return }
            guard let refreshedRootView = uiView.nearestRootInHierarchy else { return }
            guard refreshedRootView.firstResponderDescendant == nil else {
                context.coordinator.didFocus = true
                return
            }

            if let firstInput = refreshedRootView.firstFocusableTextInput {
                context.coordinator.didFocus = firstInput.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var didFocus = false
    }
}

private extension UIView {
    var nearestRootInHierarchy: UIView? {
        var current: UIView? = self
        var lastValid: UIView?
        while let view = current {
            lastValid = view
            current = view.superview
        }
        return lastValid
    }

    var firstResponderDescendant: UIResponder? {
        if isFirstResponder {
            return self
        }

        for subview in subviews {
            if let responder = subview.firstResponderDescendant {
                return responder
            }
        }
        return nil
    }

    var firstFocusableTextInput: UIResponder? {
        if let textField = self as? UITextField,
           textField.canBecomeFirstResponder,
           !textField.isHidden,
           textField.alpha > 0.01,
           textField.isUserInteractionEnabled {
            return textField
        }

        if let textView = self as? UITextView,
           textView.canBecomeFirstResponder,
           !textView.isHidden,
           textView.alpha > 0.01,
           textView.isUserInteractionEnabled {
            return textView
        }

        for subview in subviews {
            if let input = subview.firstFocusableTextInput {
                return input
            }
        }
        return nil
    }
}


#Preview {
    FormSheetView(title: "Титул", confirmTitle: "Привет", isConfirmDisabled: false) {
        //
    } cancelAction: {
        //
    } content: {
        Text("Привет")
    }

}
