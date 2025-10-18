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
                    List {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                sessionRow(session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(session)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets
                                .map { sessions[$0] }
                                .forEach(context.delete)
                        }
                    }
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
                .fontDesign(.monospaced)
            Text("Игра: \(session.gameType.rawValue)")
            Text("Блайнды: \(session.smallBlind) / \(session.bigBlind)")
                .fontDesign(.monospaced)
            
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

#Preview {
    SessionListView()
        .modelContainer(for: Session.self, inMemory: true)
        .environment(SessionDetailViewModel())
}
