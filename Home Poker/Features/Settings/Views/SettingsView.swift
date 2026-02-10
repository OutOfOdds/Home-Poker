import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Club.name)]) private var clubs: [Club]
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
    @State private var debugGenerationTask: Task<Void, Never>?
    @State private var showClearSessionsConfirm = false
    @State private var showClearDatabaseConfirm = false
#endif

    var body: some View {
        Form {

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
                    Label("Сгенерировать 10000 сессий", systemImage: "sparkles")
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
                Text("Создает тестовый клуб, добавляет участников и генерирует 10000 кеш-сессий в разных датах.")
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
        .alert("Сгенерировать 10000 сессий?", isPresented: $showGenerateConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Сгенерировать", role: .destructive) {
                startDebugSessionGeneration(count: 10000)
            }
        } message: {
            Text("Текущие debug-сессии для Debug Club будут очищены и заново сгенерированы.")
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
    @MainActor
    private func startDebugSessionGeneration(count: Int) {
        guard count > 0, !isGeneratingDebugSessions else { return }

        isGeneratingDebugSessions = true
        let container = context.container

        debugGenerationTask?.cancel()
        debugGenerationTask = Task(priority: .userInitiated) {
            do {
                try await Self.generateRandomSessions(count: count, in: container)
            } catch is CancellationError {
                // User launched a new generation task.
            } catch {
                assertionFailure("Failed to generate sessions: \(error)")
            }

            await MainActor.run {
                isGeneratingDebugSessions = false
                debugGenerationTask = nil
            }
        }
    }

    private nonisolated static func generateRandomSessions(count: Int, in container: ModelContainer) async throws {
        guard count > 0 else { return }

        let context = ModelContext(container)
        let debugClub = try fetchOrCreateDebugClub(in: context)
        let debugMembers = fetchOrCreateDebugMembers(in: debugClub)

        guard debugMembers.count >= 4 else {
            throw DebugGenerationError.insufficientMembers
        }

        try clearDebugClubData(clubID: debugClub.id, in: context)
        var aggregatesByMember: [UUID: (
            sessionsCount: Int,
            winSessionsCount: Int,
            totalBuyIn: Int,
            totalCashOut: Int,
            totalRealPnL: Int,
            totalRakeback: Int
        )] = [:]

        for index in 0..<count {
            try Task.checkCancellation()

            let status = randomSessionStatus()
            let session = makeDebugSession(
                type: .cash,
                status: status,
                in: debugClub,
                context: context
            )

            let participantCount = min(Int.random(in: 4...8), debugMembers.count)
            let participants = Array(debugMembers.shuffled().prefix(participantCount))
            populateCashSessionPlayers(in: session, participants: participants, status: status)

            let rows = buildDebugRows(for: session, clubID: debugClub.id)
            for row in rows {
                context.insert(row)
                var aggregate = aggregatesByMember[row.memberId] ?? (
                    sessionsCount: 0,
                    winSessionsCount: 0,
                    totalBuyIn: 0,
                    totalCashOut: 0,
                    totalRealPnL: 0,
                    totalRakeback: 0
                )
                aggregate.sessionsCount += 1
                if row.realPnL > 0 {
                    aggregate.winSessionsCount += 1
                }
                aggregate.totalBuyIn += row.buyIn
                aggregate.totalCashOut += row.cashOut
                aggregate.totalRealPnL += row.realPnL
                aggregate.totalRakeback += row.rakeback
                aggregatesByMember[row.memberId] = aggregate
            }

            if index % 100 == 99 {
                try context.save()
                await Task.yield()
            }
        }

        for (memberID, aggregate) in aggregatesByMember {
            let stats = ClubMemberStats(memberId: memberID, clubId: debugClub.id)
            stats.sessionsCount = aggregate.sessionsCount
            stats.winSessionsCount = aggregate.winSessionsCount
            stats.totalBuyIn = aggregate.totalBuyIn
            stats.totalCashOut = aggregate.totalCashOut
            stats.totalRealPnL = aggregate.totalRealPnL
            stats.totalRakeback = aggregate.totalRakeback
            stats.updatedAt = Date()
            context.insert(stats)
        }

        try context.save()
    }

    private func clearAllSessions() {
        do {
            let descriptor = FetchDescriptor<Session>()
            let allSessions = try context.fetch(descriptor)
            let repository = SwiftDataSessionsRepository(context: context)
            try repository.deleteSessions(allSessions)
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

    private nonisolated static func fetchOrCreateDebugClub(in context: ModelContext) throws -> Club {
        let descriptor = FetchDescriptor<Club>()
        if let existing = try context.fetch(descriptor).first(where: { $0.name == "Debug Club" }) {
            return existing
        }

        let club = Club(name: "Debug Club")
        context.insert(club)
        return club
    }

    private nonisolated static func fetchOrCreateDebugMembers(in club: Club) -> [ClubMember] {
        let memberNames: [String] = [
            "Алексей", "Михаил", "Игорь", "Павел", "Сергей", "Виктор", "Роман", "Олег",
            "Дмитрий", "Евгений", "Николай", "Андрей", "Илья", "Максим", "Кирилл", "Степан"
        ]

        var members = club.members
        var existingNames = Set(members.map { $0.name.lowercased() })

        for name in memberNames where !existingNames.contains(name.lowercased()) {
            let member = ClubMember(name: name, club: club)
            club.members.append(member)
            members.append(member)
            existingNames.insert(name.lowercased())
        }

        return members
    }

    private nonisolated static func clearDebugClubData(clubID: UUID, in context: ModelContext) throws {
        let sessionsDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.club?.id == clubID }
        )
        let rowsDescriptor = FetchDescriptor<ClubMemberSessionStats>(
            predicate: #Predicate { $0.clubId == clubID }
        )
        let aggregatesDescriptor = FetchDescriptor<ClubMemberStats>(
            predicate: #Predicate { $0.clubId == clubID }
        )

        let sessions = try context.fetch(sessionsDescriptor)
        sessions.forEach(context.delete)

        let rows = try context.fetch(rowsDescriptor)
        rows.forEach(context.delete)

        let aggregates = try context.fetch(aggregatesDescriptor)
        aggregates.forEach(context.delete)

        try context.save()
    }

    private nonisolated static func buildDebugRows(for session: Session, clubID: UUID) -> [ClubMemberSessionStats] {
        let ratio = max(session.chipsToCashRatio, 1)
        var byMember: [UUID: (
            buyIn: Int,
            cashOut: Int,
            realPnL: Int,
            rakeback: Int
        )] = [:]

        for player in session.players {
            guard let memberID = player.clubMemberID else { continue }

            let buyIn = player.chipBuyIn * ratio
            let cashOut = player.chipCashOut * ratio
            let rakeback = player.getsRakeback ? player.rakeback : 0
            let realPnL = ((player.chipCashOut - player.chipBuyIn) * ratio) + rakeback

            var accumulator = byMember[memberID] ?? (
                buyIn: 0,
                cashOut: 0,
                realPnL: 0,
                rakeback: 0
            )
            accumulator.buyIn += buyIn
            accumulator.cashOut += cashOut
            accumulator.realPnL += realPnL
            accumulator.rakeback += rakeback
            byMember[memberID] = accumulator
        }

        return byMember.map { memberID, accumulator in
            ClubMemberSessionStats(
                sessionId: session.id,
                memberId: memberID,
                clubId: clubID,
                sessionDate: session.startTime,
                sessionTitle: session.displayTitle,
                buyIn: accumulator.buyIn,
                cashOut: accumulator.cashOut,
                realPnL: accumulator.realPnL,
                rakeback: accumulator.rakeback
            )
        }
    }

    private nonisolated static func randomSessionStatus() -> SessionStatus {
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<45:
            return .active
        case 45..<75:
            return .awaitingForSettlements
        default:
            return .finished
        }
    }

    private nonisolated static func randomStartDate() -> Date {
        Date().addingTimeInterval(-Double.random(in: 0...(60 * 60 * 24 * 730)))
    }

    private nonisolated static func makeDebugSession(
        type: SessionType,
        status: SessionStatus,
        in club: Club,
        context: ModelContext
    ) -> Session {
        let session = Session(
            startTime: randomStartDate(),
            gameType: [GameType.NLHoldem, GameType.PLO4].randomElement() ?? .NLHoldem,
            sessionType: type,
            status: status,
            club: club
        )

        switch type {
        case .cash:
            session.chipsToCashRatio = [1, 2, 5, 10].randomElement() ?? 1
            let sb = [25, 50, 100, 200, 500].randomElement() ?? 50
            session.smallBlind = sb
            session.bigBlind = sb * 2
            session.ante = [0, 0, 0, 25, 50, 100].randomElement() ?? 0

        case .tournament:
            session.entryFee = [1000, 2000, 5000, 10000].randomElement() ?? 2000
            session.startingStack = [10000, 20000, 30000, 50000].randomElement() ?? 20000
            session.allowReEntry = Bool.random()
            let sb = [50, 100, 200, 300].randomElement() ?? 100
            session.smallBlind = sb
            session.bigBlind = sb * 2
            session.ante = [0, 25, 50, 75, 100].randomElement() ?? 0
        }

        context.insert(session)
        return session
    }

    private nonisolated static func populatePlayers(in session: Session, participants: [ClubMember], status: SessionStatus) {
        switch session.sessionType {
        case .cash:
            populateCashSessionPlayers(in: session, participants: participants, status: status)
        case .tournament:
            populateTournamentSessionPlayers(in: session, participants: participants, status: status)
        }
    }

    private nonisolated static func populateCashSessionPlayers(in session: Session, participants: [ClubMember], status: SessionStatus) {
        let activeCount: Int = {
            switch status {
            case .active:
                return Int.random(in: 1...max(1, participants.count / 2))
            case .awaitingForSettlements, .finished:
                return 0
            }
        }()
        let activeIndexes = Set(Array(participants.indices.shuffled().prefix(activeCount)))

        var players: [Player] = []
        var totalBuyInPerPlayer: [UUID: Int] = [:]
        var totalBuyInAll = 0

        for (index, member) in participants.enumerated() {
            let player = Player(name: member.name, inGame: activeIndexes.contains(index))
            player.clubMemberID = member.id

            let buyIn = [1000, 1500, 2000, 3000, 5000, 8000].randomElement() ?? 2000
            let buyInTransaction = PlayerChipTransaction(
                type: .chipBuyIn,
                amount: buyIn,
                player: player,
                timestamp: session.startTime.addingTimeInterval(Double.random(in: 0...3600))
            )
            player.transactions.append(buyInTransaction)

            var totalBuyIn = buyIn
            let addOnCount = Int.random(in: 0...(status == .active ? 2 : 3))
            if addOnCount > 0 {
                for addOnIndex in 0..<addOnCount where Bool.random() {
                    let addOn = [500, 1000, 1500, 2000, 3000].randomElement() ?? 1000
                    let addOnTransaction = PlayerChipTransaction(
                        type: .chipAddOn,
                        amount: addOn,
                        player: player,
                        timestamp: session.startTime.addingTimeInterval(Double((addOnIndex + 1) * 1800))
                    )
                    player.transactions.append(addOnTransaction)
                    totalBuyIn += addOn
                }
            }

            totalBuyInPerPlayer[player.id] = totalBuyIn
            totalBuyInAll += totalBuyIn
            players.append(player)
        }

        guard !players.isEmpty else { return }

        let cashOutTarget: Int = {
            switch status {
            case .active:
                return Int(Double(totalBuyInAll) * Double.random(in: 0.35...0.75))
            case .awaitingForSettlements:
                return Int(Double(totalBuyInAll) * Double.random(in: 0.90...0.99))
            case .finished:
                return Int(Double(totalBuyInAll) * Double.random(in: 0.92...1.0))
            }
        }()

        let playersForCashOut: [Player] = {
            switch status {
            case .active:
                return players.filter { !$0.inGame }
            case .awaitingForSettlements, .finished:
                return players
            }
        }()

        if !playersForCashOut.isEmpty && cashOutTarget > 0 {
            let weights = playersForCashOut.map { player in
                Double(totalBuyInPerPlayer[player.id] ?? 1) * Double.random(in: 0.6...1.8)
            }
            let payouts = distributeAmount(total: cashOutTarget, weights: weights)

            for (player, payout) in zip(playersForCashOut, payouts) where payout > 0 {
                let cashOutTransaction = PlayerChipTransaction(
                    type: .chipCashOut,
                    amount: payout,
                    player: player,
                    timestamp: session.startTime.addingTimeInterval(Double.random(in: 3600...21600))
                )
                player.transactions.append(cashOutTransaction)
            }
        }

        if status != .active {
            players.forEach { $0.inGame = false }
            let distributedCashOut = players.reduce(0) { $0 + $1.chipCashOut }
            let remainder = max(totalBuyInAll - distributedCashOut, 0)
            if remainder > 0 {
                let rake = Int(Double(remainder) * Double.random(in: 0.6...0.9))
                session.rakeAmount = rake
                session.tipsAmount = max(remainder - rake, 0)
            }
        }

        if status != .active, session.rakeAmount > 0, Bool.random() {
            let rakebackCandidates = players.filter { !$0.inGame }.shuffled()
            let rakebackCount = min(Int.random(in: 1...2), rakebackCandidates.count)
            for player in rakebackCandidates.prefix(rakebackCount) {
                player.getsRakeback = true
                player.rakeback = [100, 200, 300, 500].randomElement() ?? 100
            }
        }

        session.players.append(contentsOf: players)
    }

    private nonisolated static func populateTournamentSessionPlayers(in session: Session, participants: [ClubMember], status: SessionStatus) {
        let startingStack = max(session.startingStack ?? 20000, 1)
        let activeCount: Int = {
            switch status {
            case .active:
                return Int.random(in: 1...max(1, participants.count / 2))
            case .awaitingForSettlements, .finished:
                return 0
            }
        }()
        let activeIndexes = Set(Array(participants.indices.shuffled().prefix(activeCount)))

        var players: [Player] = []
        var totalChipsIn = 0
        var entriesCount = 0

        for (index, member) in participants.enumerated() {
            let player = Player(name: member.name, inGame: activeIndexes.contains(index))
            player.clubMemberID = member.id

            let extraEntries: Int = {
                guard session.allowReEntry else { return 0 }
                let roll = Int.random(in: 0..<100)
                switch roll {
                case 0..<60: return 0
                case 60..<88: return 1
                default: return 2
                }
            }()

            let entries = 1 + extraEntries
            entriesCount += entries

            for entryIndex in 0..<entries {
                let buyInTransaction = PlayerChipTransaction(
                    type: .chipBuyIn,
                    amount: startingStack,
                    player: player,
                    timestamp: session.startTime.addingTimeInterval(Double(entryIndex * 1200))
                )
                player.transactions.append(buyInTransaction)
            }

            totalChipsIn += entries * startingStack
            players.append(player)
        }

        let winners: [Player]
        switch status {
        case .active:
            winners = []
        case .awaitingForSettlements, .finished:
            let winnersCount = min(Int.random(in: 1...max(1, players.count / 3)), players.count)
            winners = Array(players.shuffled().prefix(winnersCount))
        }

        if !winners.isEmpty, totalChipsIn > 0 {
            let payoutTotal = totalChipsIn
            let descendingWeights = (0..<winners.count).map { index in
                Double(winners.count - index) * Double.random(in: 0.8...1.2)
            }
            let payouts = distributeAmount(total: payoutTotal, weights: descendingWeights)

            for (winner, payout) in zip(winners, payouts) where payout > 0 {
                let cashOutTransaction = PlayerChipTransaction(
                    type: .chipCashOut,
                    amount: payout,
                    player: winner,
                    timestamp: session.startTime.addingTimeInterval(Double.random(in: 7200...43200))
                )
                winner.transactions.append(cashOutTransaction)
            }
        }

        if status != .active {
            players.forEach { $0.inGame = false }
        }

        if let entryFee = session.entryFee {
            session.prizePoolTotal = entryFee * entriesCount
        }

        session.players.append(contentsOf: players)
    }

    private nonisolated static func distributeAmount(total: Int, weights: [Double]) -> [Int] {
        guard total > 0, !weights.isEmpty else {
            return Array(repeating: 0, count: weights.count)
        }

        let safeWeights = weights.map { max($0, 0.0001) }
        let totalWeight = safeWeights.reduce(0, +)
        guard totalWeight > 0 else {
            return Array(repeating: 0, count: weights.count)
        }

        var amounts = safeWeights.map { weight in
            Int((Double(total) * weight / totalWeight).rounded(.down))
        }

        var remainder = total - amounts.reduce(0, +)
        var indexes = Array(amounts.indices).shuffled()
        while remainder > 0 {
            if indexes.isEmpty {
                indexes = Array(amounts.indices).shuffled()
            }
            let index = indexes.removeLast()
            amounts[index] += 1
            remainder -= 1
        }

        return amounts
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try context.fetch(descriptor)
        items.forEach(context.delete)
    }
    #endif
}

#if DEBUG
private enum DebugGenerationError: LocalizedError {
    case insufficientMembers

    var errorDescription: String? {
        switch self {
        case .insufficientMembers:
            return "Недостаточно участников для генерации тестовых сессий."
        }
    }
}
#endif

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
