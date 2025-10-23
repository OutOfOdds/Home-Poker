import SwiftUI
import SwiftData

struct SessionListView: View {
    
    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @State private var showingNewSession = false
    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Нет сессий",
                        systemImage: "tray",
                        description: Text("Нажмите «+», чтобы добавить новую сессию")
                    )
                } else {
                    sessionList
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
    
    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    sessionRow(session)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteSessions([session])
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                let items = offsets.map { sessions[$0] }
                deleteSessions(items)
            }
        }
    }
    
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading) {
            Text((session.sessionTitle))
                .font(.title3)
                .bold()
                .monospaced()
            HStack {
                Text("Дата:")
                Text(session.startTime, format: .dateTime)
            }
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
            Text("Локация: \(session.location)")
                .foregroundStyle(.secondary)

            Text("Игра: \(session.gameType.rawValue)")
                .foregroundStyle(.secondary)

            Text("Блайнды: \(session.smallBlind.asCurrency()) / \(session.bigBlind.asCurrency())")
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)

            if session.status == .active {
                Text(session.status.rawValue)
                    .foregroundStyle(.green)
            }
            
            if session.status == .finished {
                Text(session.status.rawValue)
                    .foregroundStyle(.blue)
            }
        }
    }
}

private extension SessionListView {
    func deleteSessions(_ sessions: [Session]) {
        guard !sessions.isEmpty else { return }
        let repository = SwiftDataSessionsRepository(context: context)
        do {
            try repository.deleteSessions(sessions)
        } catch {
            assertionFailure("Failed to delete sessions: \\(error)")
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(PreviewData.previewContainer)
        .environment(SessionDetailViewModel())
}
