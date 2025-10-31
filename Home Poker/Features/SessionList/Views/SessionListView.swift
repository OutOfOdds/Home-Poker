import SwiftUI
import SwiftData

struct SessionListView: View {
    
    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @State private var showingNewSession = false
    @AppStorage("sessionListShowDetails") private var showSessionDetails = true
    @State private var sessionToDelete: Session?
    
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
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Новая")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewSessionSheet()
            }
            .alert("Удалить сессию?", isPresented: .constant(sessionToDelete != nil)) {
                Button("Отмена", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("Удалить", role: .destructive) {
                    if let session = sessionToDelete {
                        deleteSessions([session])
                        sessionToDelete = nil
                    }
                }
            } message: {
                if let session = sessionToDelete {
                    Text("Вы уверены, что хотите удалить сессию «\(session.sessionTitle)»? Это действие нельзя отменить.")
                }
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        sessionToDelete = session
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    sessionToDelete = sessions[index]
                }
            }
        }
    }
    
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.sessionTitle)
                .font(.title3)
                .bold()
            if showSessionDetails {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(session.startTime, format: .dateTime)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.secondary)
                    Text("\(session.location)")
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "suit.club.fill")
                        .foregroundStyle(.secondary)
                    Text("\(session.gameType.rawValue) • \(session.smallBlind.asCurrency()) / \(session.bigBlind.asCurrency())")
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(session.status.rawValue)
                        .font(.footnote.weight(.semibold))
                        .padding(5)
                        .background(statusColor(for: session.status).opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor(for: session.status))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(session.startTime, format: .dateTime)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func statusIcon(for status: SessionStatus) -> String {
        switch status {
        case .active: return "bolt.fill"
        case .awaitingForSettlements: return "hourglass"
        case .finished: return "checkmark.seal.fill"
        }
    }
    
    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active: return .green
        case .awaitingForSettlements: return .orange
        case .finished: return .blue
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
