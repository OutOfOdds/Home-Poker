import SwiftUI

/// UIKit Activity View Controller обертка для SwiftUI для шеринга.
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
