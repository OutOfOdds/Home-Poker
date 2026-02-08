import SwiftUI
import SwiftData

/// Router view that delegates to the appropriate detail view based on session type
struct SessionDetailView: View {
    @Bindable var session: Session

    var body: some View {
        switch session.sessionType {
        case .cash:
            CashSessionDetailView(session: session)
        case .tournament:
            TournamentSessionDetailView(session: session)
        }
    }
}

#Preview("Кеш-игра") {
    NavigationStack {
        SessionDetailView(session: PreviewData.activeSession())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(PreviewData.previewContainer)
}

#Preview("Турнир") {
    @Previewable @State var tournamentSession = Session(
        startTime: Date(),
        gameType: .NLHoldem,
        sessionType: .tournament,
        status: .active
    )

    NavigationStack {
        SessionDetailView(session: tournamentSession)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(PreviewData.previewContainer)
}
