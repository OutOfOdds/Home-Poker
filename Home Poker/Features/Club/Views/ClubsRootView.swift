import SwiftUI
import SwiftData

struct ClubsRootView: View {
    var body: some View {
        ClubListView()
    }
}

#Preview {
    ClubsRootView()
        .modelContainer(PreviewData.previewContainer)
}
