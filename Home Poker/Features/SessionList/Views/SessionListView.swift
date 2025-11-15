import SwiftUI
import SwiftData

struct SessionListView: View {

    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @State private var showingNewSession = false
    @AppStorage("sessionListShowDetails") private var showSessionDetails = true
    @State private var sessionToDelete: Session?

    // Import
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError: Error?
    @State private var importedSession: Session?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()
    
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
                    Menu {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Настройки", systemImage: "gearshape")
                        }

                        Button {
                            showImportPicker = true
                        } label: {
                            Label("Импорт сессии", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.pokerSession],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Сессия импортирована", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                if let session = importedSession {
                    Text("Сессия «\(session.sessionTitle)» успешно импортирована")
                }
            }
            .alert("Ошибка импорта", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError?.localizedDescription ?? "Не удалось импортировать сессию")
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

    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            importSession(from: fileURL)
        case .failure(let error):
            importError = error
            showImportError = true
        }
    }

    func importSession(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw TransferError.fileAccessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let session = try transferService.importSession(from: data, into: context)

            importedSession = session
            showImportSuccess = true
        } catch {
            importError = error
            showImportError = true
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(PreviewData.previewContainer)
        .environment(SessionDetailViewModel())
}
