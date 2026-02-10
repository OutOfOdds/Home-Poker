import SwiftUI
import SwiftData

struct ClubSessionsView: View {
    @Bindable var club: Club

    @Environment(\.modelContext) private var context
    @State private var loadedSessions: [Session] = []
    @State private var isLoadingPage = false
    @State private var hasLoadedInitialPage = false
    @State private var hasMorePages = true
    @State private var nextFetchOffset = 0
    @State private var showingNewCashSession = false
    @State private var showingNewTournamentSession = false
    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false
    
    // Export
    @State private var sessionToExport: Session?
    @State private var exportedFileURL: URL?
    @State private var showExportError = false
    @State private var exportError: Error?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()
    private let pageSize = 100
    private let paginationTriggerDistance = 20

    init(club: Club) {
        self.club = club
    }
    
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
            .sheet(isPresented: $showingNewCashSession, onDismiss: reloadSessions) {
                NewSessionSheet(sessionType: .cash, club: club)
            }
            .sheet(isPresented: $showingNewTournamentSession, onDismiss: reloadSessions) {
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
                        if deleteSessions([selectedSession]) {
                            reloadSessions()
                        }
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
            .task(id: club.id) {
                await MainActor.run {
                    reloadSessions()
                }
            }
    }
    
    private var sessionList: some View {
        Group {
            if !hasLoadedInitialPage && isLoadingPage {
                List {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if loadedSessions.isEmpty {
                List {
                    ContentUnavailableView(
                        "Нет сессий",
                        systemImage: "tray",
                        description: Text("Добавьте первую сессию для клуба")
                    )
                }
            } else {
                List {
                    ForEach(loadedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        .onAppear {
                            loadNextPageIfNeeded(current: session)
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

                    if isLoadingPage {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowSpacing(8)
            }
        }
    }
    
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }
    
    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active: return .green
        case .awaitingForSettlements: return .orange
        case .finished: return .blue
        }
    }

    private func reloadSessions() {
        loadedSessions = []
        nextFetchOffset = 0
        hasMorePages = true
        hasLoadedInitialPage = false
        loadNextPage()
    }

    private func loadNextPage() {
        guard hasMorePages, !isLoadingPage else { return }
        isLoadingPage = true
        defer {
            isLoadingPage = false
            hasLoadedInitialPage = true
        }

        let clubID = club.id
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.club?.id == clubID
            },
            sortBy: [SortDescriptor(\Session.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = nextFetchOffset

        do {
            let page = try context.fetch(descriptor)
            loadedSessions.append(contentsOf: page)
            nextFetchOffset += page.count
            hasMorePages = page.count == pageSize
        } catch {
            hasMorePages = false
            assertionFailure("Failed to fetch sessions page: \(error)")
        }
    }

    private func loadNextPageIfNeeded(current session: Session) {
        guard hasLoadedInitialPage, hasMorePages, !isLoadingPage else { return }
        let isNearEnd = loadedSessions
            .suffix(paginationTriggerDistance)
            .contains { $0.id == session.id }
        if isNearEnd {
            loadNextPage()
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
    
    @discardableResult
    func deleteSessions(_ sessions: [Session]) -> Bool {
        guard !sessions.isEmpty else { return true }
        let repository = SwiftDataSessionsRepository(context: context)
        do {
            try repository.deleteSessions(sessions)
            return true
        } catch {
            assertionFailure("Failed to delete sessions: \(error)")
            return false
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
