import SwiftUI

struct FormSheetView<Content: View>: View {
    let title: String
    let confirmTitle: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    let isConfirmDisabled: Bool
    @ViewBuilder var content: Content

    init(
        title: String,
        confirmTitle: String,
        isConfirmDisabled: Bool = false,
        confirmAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.confirmAction = confirmAction
        self.cancelAction = cancelAction
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена", action: cancelAction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle, action: confirmTapped)
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
