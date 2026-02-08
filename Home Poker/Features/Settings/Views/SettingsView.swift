import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Club.name)]) private var clubs: [Club]
    @AppStorage("sessionListShowDetails") private var showSessionListDetails = true
    @AppStorage("timerNotificationsEnabled") private var timerNotificationsEnabled = true

    // Import
    @State private var showImportPicker = false
    @State private var showImportSetupSheet = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError: Error?
    @State private var importedSession: Session?
    @State private var pendingImportData: Data?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()

#if DEBUG
@State private var showGenerateConfirm = false
@State private var isGeneratingDebugSessions = false
@State private var showClearSessionsConfirm = false
@State private var showClearDatabaseConfirm = false
#endif

    var body: some View {
        Form {

            Section {
                Toggle("Показывать подробности", isOn: $showSessionListDetails)
            }
            header: {
                Text("Список сессий")
            }
            footer: {
                Text("Когда выключено — в списке отображается только название и дата последней игры.")
                    .font(.footnote)
            }

            Section {
                Toggle("Уведомления при смене уровня", isOn: $timerNotificationsEnabled)
            } header: {
                Text("Таймер блайндов")
            } footer: {
                Text("Получать уведомления при автоматической смене уровня блайндов в турнире")
            }

            Section {
                NavigationLink {
                    KnowledgeBaseView()
                } label: {
                    Label("База знаний", systemImage: "book.fill")
                }
            } header: {
                Text("Помощь")
            }
            
            
            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Импортировать сессию", systemImage: "square.and.arrow.down")
                }
                .disabled(clubs.isEmpty)

                if clubs.isEmpty {
                    Text("Сначала создайте хотя бы один клуб.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Импорт")
            } footer: {
                Text("Импортируйте сессию из файла .pokersession, полученного от другого пользователя.")
                    .font(.footnote)
            }

            #if DEBUG
            Section {
                Button {
                    showGenerateConfirm = true
                } label: {
                    Label("Сгенерировать 1000 сессий", systemImage: "sparkles")
                }
                .disabled(isGeneratingDebugSessions)

                Button(role: .destructive) {
                    showClearSessionsConfirm = true
                } label: {
                    Label("Очистить все сессии", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showClearDatabaseConfirm = true
                } label: {
                    Label("Очистить всю базу", systemImage: "trash.slash")
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("Добавляет 1000 случайных сессий в базу для тестирования списка.")
                    .font(.footnote)
            }
            #endif
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.pokerSession],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showImportSetupSheet) {
            if let pendingImportData {
                ImportSessionSetupSheet(
                    clubs: clubs,
                    importData: pendingImportData,
                    transferService: transferService
                ) { club, selectedMissingMemberNames in
                    importPendingSession(into: club, addingClubMembers: selectedMissingMemberNames)
                } onCancel: {
                    resetPendingImportFlow()
                }
            } else {
                EmptyView()
            }
        }
        .alert("Сессия импортирована", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            if let session = importedSession {
                Text("Сессия «\(session.displayTitle)» успешно импортирована")
            }
        }
        .alert("Ошибка импорта", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError?.localizedDescription ?? "Не удалось импортировать сессию")
        }
        #if DEBUG
        .alert("Сгенерировать 1000 сессий?", isPresented: $showGenerateConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Сгенерировать", role: .destructive) {
                generateRandomSessions(count: 1000)
            }
        } message: {
            Text("Это добавит 1000 случайных записей в базу данных.")
        }
        .alert("Очистить все сессии?", isPresented: $showClearSessionsConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Очистить", role: .destructive) {
                clearAllSessions()
            }
        } message: {
            Text("Все сессии и связанные данные будут удалены без возможности восстановления.")
        }
        .alert("Очистить всю базу?", isPresented: $showClearDatabaseConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Очистить", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("Будут удалены все сессии, игроки, расходы, банк и переводы. Действие необратимо.")
        }
        #endif
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            prepareImport(from: fileURL)
        case .failure(let error):
            importError = error
            showImportError = true
        }
    }

    private func prepareImport(from url: URL) {
        do {
            guard !clubs.isEmpty else {
                throw SettingsImportError.noClubsAvailable
            }
            guard url.startAccessingSecurityScopedResource() else {
                throw TransferError.fileAccessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            pendingImportData = try Data(contentsOf: url)
            showImportSetupSheet = true
        } catch {
            importError = error
            showImportError = true
        }
    }

    private func importPendingSession(into club: Club, addingClubMembers names: [String]) {
        guard let pendingImportData else { return }
        do {
            let session = try transferService.importSession(
                from: pendingImportData,
                into: context,
                in: club,
                addingClubMembers: names
            )
            importedSession = session
            showImportSuccess = true
            resetPendingImportFlow()
        } catch {
            importError = error
            showImportError = true
            resetPendingImportFlow()
        }
    }

    private func resetPendingImportFlow() {
        pendingImportData = nil
        showImportSetupSheet = false
    }

    #if DEBUG
    private func generateRandomSessions(count: Int) {
        guard count > 0 else { return }
        isGeneratingDebugSessions = true
        defer { isGeneratingDebugSessions = false }

        let debugClub: Club
        do {
            debugClub = try fetchOrCreateDebugClub()
        } catch {
            assertionFailure("Failed to resolve debug club: \(error)")
            return
        }

        for _ in 1...count {
            let sessionType = [SessionType.cash, SessionType.tournament].randomElement() ?? .cash
            let gameType = [GameType.NLHoldem, GameType.PLO4].randomElement() ?? .NLHoldem
            let status = [SessionStatus.active, .awaitingForSettlements, .finished].randomElement() ?? .active
            let startTime = Date().addingTimeInterval(-Double.random(in: 0...(60 * 60 * 24 * 730)))

            var input = NewSessionInput(
                startTime: startTime,
                gameType: gameType,
                sessionType: sessionType,
                cashToChipsRatio: nil,
                entryFee: nil,
                startingStack: nil,
                allowReEntry: nil,
                smallBlind: nil,
                bigBlind: nil,
                ante: nil
            )

            if sessionType == .cash {
                input.cashToChipsRatio = [1, 2, 5, 10].randomElement() ?? 1
                let sb = [25, 50, 100, 200, 500].randomElement() ?? 50
                input.smallBlind = sb
                input.bigBlind = sb * 2
                input.ante = [0, 0, 0, 25, 50].randomElement() ?? 0
            } else {
                input.entryFee = [1000, 2000, 5000, 10000].randomElement() ?? 1000
                input.startingStack = [20000, 30000, 50000, 100000].randomElement() ?? 20000
                input.allowReEntry = Bool.random()
                let sb = [50, 100, 200].randomElement() ?? 50
                input.smallBlind = sb
                input.bigBlind = sb * 2
                input.ante = [0, 25, 50].randomElement() ?? 0
            }

            let session = Session(
                startTime: input.startTime,
                gameType: input.gameType,
                sessionType: input.sessionType,
                status: status,
                club: debugClub
            )

            if input.sessionType == .cash {
                if let ratio = input.cashToChipsRatio, ratio > 0 {
                    session.chipsToCashRatio = ratio
                }
            }

            if input.sessionType == .tournament {
                session.entryFee = input.entryFee
                session.startingStack = input.startingStack
                session.allowReEntry = input.allowReEntry ?? false
            }

            if let sb = input.smallBlind, sb > 0 {
                session.smallBlind = sb
            }
            if let bb = input.bigBlind, bb > 0 {
                session.bigBlind = bb
            }
            if let ante = input.ante, ante >= 0 {
                session.ante = ante
            }

            context.insert(session)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to generate sessions: \(error)")
        }
    }

    private func clearAllSessions() {
        do {
            let descriptor = FetchDescriptor<Session>()
            let allSessions = try context.fetch(descriptor)
            allSessions.forEach(context.delete)
            try context.save()
        } catch {
            assertionFailure("Failed to clear sessions: \(error)")
        }
    }

    private func clearAllData() {
        do {
            try deleteAll(ExpenseDistribution.self)
            try deleteAll(Expense.self)
            try deleteAll(SessionBankTransaction.self)
            try deleteAll(SessionBank.self)
            try deleteAll(SettlementTransfer.self)
            try deleteAll(PlayerChipTransaction.self)
            try deleteAll(Player.self)
            try deleteAll(Session.self)
            try deleteAll(ClubMemberSessionStats.self)
            try deleteAll(ClubMemberStats.self)
            try deleteAll(ClubMember.self)
            try deleteAll(Club.self)
            try context.save()
        } catch {
            assertionFailure("Failed to clear database: \(error)")
        }
    }

    private func fetchOrCreateDebugClub() throws -> Club {
        let descriptor = FetchDescriptor<Club>()
        if let existing = try context.fetch(descriptor).first(where: { $0.name == "Debug Club" }) {
            return existing
        }

        let club = Club(name: "Debug Club")
        context.insert(club)
        return club
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try context.fetch(descriptor)
        items.forEach(context.delete)
    }
    #endif
}

private enum SettingsImportError: LocalizedError {
    case noClubsAvailable

    var errorDescription: String? {
        switch self {
        case .noClubsAvailable:
            return "Сначала создайте клуб, чтобы импортировать сессию."
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
