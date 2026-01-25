import Foundation
import Observation
import SwiftData

@Observable
final class SettlementViewModel {
    @ObservationIgnored private let service: SettlementProtocol
    @ObservationIgnored private let bankService: SessionServiceProtocol

    var balances: [PlayerBalance]
    var bankTransfers: [BankTransfer]
    var returnTransfers: [ReturnToBankTransfer]
    var playerToBankTransfers: [PlayerToBankTransfer]
    var transfers: [TransferProposal]

    /// Сохраненные переводы из базы данных
    var persistedTransfers: [SettlementTransfer] = []

    // Базовый инициализатор
    init(
        service: SettlementProtocol = SettlementService(),
        bankService: SessionServiceProtocol = SessionService(),
        balances: [PlayerBalance] = [],
        bankTransfers: [BankTransfer] = [],
        returnTransfers: [ReturnToBankTransfer] = [],
        playerToBankTransfers: [PlayerToBankTransfer] = [],
        transfers: [TransferProposal] = []
    ) {
        self.service = service
        self.bankService = bankService
        self.balances = balances
        self.bankTransfers = bankTransfers
        self.returnTransfers = returnTransfers
        self.playerToBankTransfers = playerToBankTransfers
        self.transfers = transfers
    }

    // Удобный инициализатор из Session
    convenience init(
        session: Session,
        service: SettlementProtocol = SettlementService()
    ) {
        self.init(service: service)
        calculate(for: session)
    }

    // MARK: - Settlement Calculation

    /// Пересчет на основе текущего состояния сессии с учётом банка
    func calculate(for session: Session) {
        let result = service.calculate(for: session)
        self.balances = result.balances
        self.bankTransfers = result.bankTransfers
        self.transfers = result.playerTransfers
        self.returnTransfers = result.returnToBankTransfers
        self.playerToBankTransfers = result.playerToBankTransfers
    }

    // MARK: - Settlement Transfer Management

    /// Загружает сохраненные переводы из базы данных
    func loadPersistedTransfers(for session: Session, context: ModelContext) {
        let sessionID = session.id
        let descriptor = FetchDescriptor<SettlementTransfer>(
            predicate: #Predicate { transfer in
                transfer.session.id == sessionID
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            persistedTransfers = try context.fetch(descriptor)
            print("📊 Loaded \(persistedTransfers.count) persisted transfers")
        } catch {
            print("❌ Failed to load transfers: \(error)")
            persistedTransfers = []
        }
    }

    /// Создает переводы в базе данных
    func saveTransfers(for session: Session, context: ModelContext) throws {
        // Создаем переводы из банка
        for bankTransfer in bankTransfers {
            let transfer = SettlementTransfer(
                session: session,
                fromPlayer: nil,
                toPlayer: bankTransfer.to,
                amount: bankTransfer.amount,
                transferType: .bankToPlayer
            )
            context.insert(transfer)
        }

        // Создаем переводы в банк
        for returnTransfer in returnTransfers {
            let transfer = SettlementTransfer(
                session: session,
                fromPlayer: returnTransfer.from,
                toPlayer: nil,
                amount: returnTransfer.amount,
                transferType: .playerToBank,
                note: returnTransfer.expenseNote
            )
            context.insert(transfer)
        }

        // Создаем переводы в банк по итогам игры
        for playerToBankTransfer in playerToBankTransfers {
            let transfer = SettlementTransfer(
                session: session,
                fromPlayer: playerToBankTransfer.from,
                toPlayer: nil,
                amount: playerToBankTransfer.amount,
                transferType: .playerToBank
            )
            context.insert(transfer)
        }

        // Создаем переводы между игроками
        for playerTransfer in transfers {
            let transfer = SettlementTransfer(
                session: session,
                fromPlayer: playerTransfer.from,
                toPlayer: playerTransfer.to,
                amount: playerTransfer.amount,
                transferType: .playerToPlayer
            )
            context.insert(transfer)
        }

        try context.save()
        loadPersistedTransfers(for: session, context: context)
    }

    /// Переключает статус выполнения перевода
    func toggleTransferStatus(
        _ transfer: SettlementTransfer,
        session: Session,
        context: ModelContext
    ) throws {
        if transfer.transferType == .playerToPlayer {
            transfer.toggleCompletion()
            try context.save()
            loadPersistedTransfers(for: transfer.session, context: context)
            return
        }

        if transfer.isCompleted {
            if let linkedId = transfer.linkedBankTransactionId {
                try removeLinkedBankTransaction(linkedId, from: session, context: context)
                transfer.linkedBankTransactionId = nil
            }
            transfer.markAsIncomplete()
        } else {
            let transaction = try createBankTransaction(for: transfer, session: session)
            transfer.linkedBankTransactionId = transaction.id
            transfer.markAsCompleted()
        }

        try context.save()
        loadPersistedTransfers(for: transfer.session, context: context)
    }

    private func createBankTransaction(
        for transfer: SettlementTransfer,
        session: Session
    ) throws -> SessionBankTransaction {
        let bank = bankService.ensureBank(for: session)
        let amount = transfer.amount
        let note = transfer.note?.trimmed

        switch transfer.transferType {
        case .bankToPlayer:
            guard let player = transfer.toPlayer else {
                throw SessionServiceError.invalidAmount
            }
            guard bank.netBalance >= amount else {
                throw SessionServiceError.insufficientBankBalance
            }
            let finalNote = note ?? "Расчет: выдача из кассы"
            let transaction = SessionBankTransaction(
                amount: amount,
                type: .withdrawal,
                player: player,
                bank: bank,
                note: finalNote
            )
            bank.transactions.append(transaction)
            return transaction
        case .playerToBank:
            guard let player = transfer.fromPlayer else {
                throw SessionServiceError.invalidAmount
            }
            let finalNote = note ?? "Расчет: перевод в кассу"
            let transaction = SessionBankTransaction(
                amount: amount,
                type: .deposit,
                player: player,
                bank: bank,
                note: finalNote
            )
            bank.transactions.append(transaction)
            return transaction
        case .playerToPlayer:
            throw SessionServiceError.invalidAmount
        }
    }

    private func removeLinkedBankTransaction(
        _ transactionId: UUID,
        from session: Session,
        context: ModelContext
    ) throws {
        guard let bank = session.bank else { return }
        guard let transaction = bank.transactions.first(where: { $0.id == transactionId }) else { return }
        try bankService.removeBankTransaction(transaction, from: session)
    }

    /// Принудительно пересоздает переводы (удаляет старые и создает новые)
    func recreateTransfers(for session: Session, context: ModelContext) throws {
        let sessionID = session.id
        let descriptor = FetchDescriptor<SettlementTransfer>(
            predicate: #Predicate { transfer in
                transfer.session.id == sessionID
            }
        )

        let oldTransfers = try context.fetch(descriptor)
        print("🗑️ Recreating: deleting \(oldTransfers.count) old transfers")
        oldTransfers.forEach { context.delete($0) }

        try saveTransfers(for: session, context: context)
    }

    // MARK: - Matching Transfers

    /// Находит соответствующий сохраненный transfer для player transfer
    func findMatchingTransfer(for proposal: TransferProposal) -> SettlementTransfer? {
        return persistedTransfers.first { transfer in
            transfer.transferType == .playerToPlayer &&
            transfer.fromPlayer?.id == proposal.from.id &&
            transfer.toPlayer?.id == proposal.to.id &&
            transfer.amount == proposal.amount
        }
    }

    /// Находит соответствующий сохраненный transfer для bank transfer
    func findMatchingTransfer(for bankTransfer: BankTransfer) -> SettlementTransfer? {
        return persistedTransfers.first { transfer in
            transfer.transferType == .bankToPlayer &&
            transfer.fromPlayer == nil &&
            transfer.toPlayer?.id == bankTransfer.to.id &&
            transfer.amount == bankTransfer.amount
        }
    }

    /// Находит соответствующий сохраненный transfer для return transfer
    func findMatchingTransfer(for returnTransfer: ReturnToBankTransfer) -> SettlementTransfer? {
        return persistedTransfers.first { transfer in
            transfer.transferType == .playerToBank &&
            transfer.fromPlayer?.id == returnTransfer.from.id &&
            transfer.toPlayer == nil &&
            transfer.amount == returnTransfer.amount &&
            transfer.note == returnTransfer.expenseNote
        }
    }

    /// Находит соответствующий сохраненный transfer для переводов в кассу
    func findMatchingTransfer(for playerToBankTransfer: PlayerToBankTransfer) -> SettlementTransfer? {
        return persistedTransfers.first { transfer in
            transfer.transferType == .playerToBank &&
            transfer.fromPlayer?.id == playerToBankTransfer.from.id &&
            transfer.toPlayer == nil &&
            transfer.amount == playerToBankTransfer.amount &&
            transfer.note == nil
        }
    }

    // MARK: - Computed Properties

    /// Проверяет, есть ли хотя бы один сохраненный перевод
    var hasPersistedTransfers: Bool {
        !persistedTransfers.isEmpty
    }

    /// Количество выполненных переводов
    var completedTransfersCount: Int {
        persistedTransfers.filter { $0.isCompleted }.count
    }

    /// Общее количество переводов
    var totalTransfersCount: Int {
        persistedTransfers.count
    }

    /// Прогресс выполнения в процентах (0.0 ... 1.0)
    var completionProgress: Double {
        guard totalTransfersCount > 0 else { return 0.0 }
        return Double(completedTransfersCount) / Double(totalTransfersCount)
    }
}
