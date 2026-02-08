import SwiftUI
import SwiftData

struct ClubSessionsView: View {
    @Bindable var club: Club
    
    @Environment(\.modelContext) private var context
    @State private var showingNewCashSession = false
    @State private var showingNewTournamentSession = false
    @AppStorage("sessionListShowDetails") private var showSessionDetails = true
    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false
    
    // Export
    @State private var sessionToExport: Session?
    @State private var exportedFileURL: URL?
    @State private var showExportError = false
    @State private var exportError: Error?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()
    
    var body: some View {
        sessionList
            .navigationTitle(club.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ClubMembersView(club: club)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.3")
                            Text("Участники")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingNewCashSession = true
                        } label: {
                            Label("Кеш-игра", systemImage: "dollarsign.circle")
                        }
                        
                        Button {
                            showingNewTournamentSession = true
                        } label: {
                            Label("Турнир", systemImage: "trophy")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Новая")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewCashSession) {
                NewSessionSheet(sessionType: .cash, club: club)
            }
            .sheet(isPresented: $showingNewTournamentSession) {
                NewSessionSheet(sessionType: .tournament, club: club)
            }
            .sheet(isPresented: .constant(exportedFileURL != nil)) {
                if let exportedFileURL {
                    ActivityViewController(activityItems: [exportedFileURL]) {
                        self.exportedFileURL = nil
                        sessionToExport = nil
                    }
                }
            }
            .alert("Удалить сессию?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("Удалить", role: .destructive) {
                    if let selectedSession = sessionToDelete {
                        deleteSessions([selectedSession])
                        sessionToDelete = nil
                    }
                }
            } message: {
                if let sessionToDelete {
                    Text("\nВы уверены, что хотите удалить сессию «\(sessionToDelete.displayTitle)»?\n\nЭто действие нельзя отменить.")
                }
            }
            .alert("Ошибка экспорта", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError?.localizedDescription ?? "Не удалось экспортировать сессию")
            }
    }
    
    private var sortedSessions: [Session] {
        club.sessions.sorted { $0.startTime > $1.startTime }
    }
    
    private var sessionList: some View {
        Group {
            if sortedSessions.isEmpty {
                List {
                    ContentUnavailableView(
                        "Нет сессий",
                        systemImage: "tray",
                        description: Text("Добавьте первую сессию для клуба")
                    )
                }
            } else {
                List {
                    ForEach(sortedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                exportSession(session)
                            } label: {
                                Label("Поделиться", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                sessionToDelete = session
                                showDeleteConfirmation = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowSpacing(8)
            }
        }
    }
    
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            
            if showSessionDetails {
                HStack(spacing: 8) {
                    Image(systemName: session.sessionType == .cash ? "banknote" : "trophy")
                        .foregroundStyle(.secondary)
                    Text(session.startTime, format: .dateTime)
                    Group {
                        Text(session.sessionType == .cash ? "| Cash Game" : "| Tournament")
                    }
                    .foregroundStyle(.secondary)
                }
                
                Text("\(session.gameType.rawValue) | \(session.smallBlind.asCurrency()) / \(session.bigBlind.asCurrency())")
                    .foregroundStyle(.secondary)
                
                Text(session.status.rawValue)
                    .font(.footnote.weight(.semibold))
                    .padding(5)
                    .background(statusColor(for: session.status).opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor(for: session.status))
                    .glassEffect()
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
    
    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active: return .green
        case .awaitingForSettlements: return .orange
        case .finished: return .blue
        }
    }
}

private extension ClubSessionsView {
    func exportSession(_ session: Session) {
        sessionToExport = session
        do {
            let data = try transferService.exportSession(session)
            let filename = generateFilename(for: session)
            let url = try saveToTemporaryFile(data: data, filename: filename)
            exportedFileURL = url
        } catch {
            exportError = error
            showExportError = true
        }
    }
    
    func generateFilename(for session: Session) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let dateString = dateFormatter.string(from: session.startTime)

        let clubName = session.club?.name ?? club.name
        let compactClubName = clubName
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let sanitizedClubName = compactClubName
            .components(separatedBy: invalidCharacters)
            .joined()
        let finalClubName = sanitizedClubName.isEmpty ? "Club" : sanitizedClubName

        return "\(dateString)-\(finalClubName).pokersession"
    }
    
    func saveToTemporaryFile(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func deleteSessions(_ sessions: [Session]) {
        guard !sessions.isEmpty else { return }
        let repository = SwiftDataSessionsRepository(context: context)
        do {
            try repository.deleteSessions(sessions)
        } catch {
            assertionFailure("Failed to delete sessions: \(error)")
        }
    }
}

#Preview {
    let container = PreviewData.previewContainer
    let context = container.mainContext
    let club = (try? context.fetch(FetchDescriptor<Club>()).first) ?? Club(name: "Домашний клуб")
    
    NavigationStack {
        ClubSessionsView(club: club)
    }
    .modelContainer(container)
    .environment(SessionDetailViewModel())
}
