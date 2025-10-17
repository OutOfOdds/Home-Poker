import SwiftUI
import SwiftData

struct SessionListView: View {

    @Query private var sessions: [Session]
    @State private var viewModel = SessionListViewModel()
    @State private var showingNewSession = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        sessionRow(session)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.delete(session)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteSessions(at: offsets, from: sessions)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewSessionSheet()
            }
            .navigationTitle("Сессии")
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading) {
            Text(session.startTime, format: .dateTime)
            Text("Игра: \(session.gameType.rawValue)")
            Text("Блайнды: \(session.smallBlind)/\(session.bigBlind)")

            if session.status == .active {
                Text(session.status.rawValue)
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: Session.self, inMemory: true)
}
