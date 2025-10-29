import Foundation
import SwiftData

@Model
final class SessionBank {
    @Attribute(.unique) var id: UUID = UUID()
    @Relationship(inverse: \Session.bank) var session: Session
    @Relationship var manager: Player?
    @Relationship(deleteRule: .cascade) var transactions: [SessionBankTransaction] = []
    var createdAt: Date
    var isClosed: Bool
    var closedAt: Date?
    var expectedTotal: Int
    
    var netBalance: Int {
        totalDeposited - totalWithdrawn
    }
    
    var remainingToCollect: Int {
        max(expectedTotal - totalDeposited, 0)
    }

    init(
        session: Session,
        manager: Player? = nil,
        createdAt: Date = Date(),
        isClosed: Bool = false,
        closedAt: Date? = nil,
        expectedTotal: Int = 0
    ) {
        self.session = session
        self.manager = manager
        self.createdAt = createdAt
        self.isClosed = isClosed
        self.closedAt = closedAt
        self.expectedTotal = expectedTotal
    }
}

extension SessionBank {
    /// Вычисляет общие суммы пополнений и выдач за один проход по всем записям.
    /// - Returns: Кортеж с суммой пополнений и суммой выдач.
    private func calculateTotals() -> (deposited: Int, withdrawn: Int) {
        transactions.reduce((deposited: 0, withdrawn: 0)) { result, entry in
            switch entry.type {
            case .deposit:
                return (result.deposited + entry.amount, result.withdrawn)
            case .withdrawal:
                return (result.deposited, result.withdrawn + entry.amount)
            }
        }
    }

    var totalDeposited: Int {
        calculateTotals().deposited
    }

    var totalWithdrawn: Int {
        calculateTotals().withdrawn
    }

    func contributions(for player: Player) -> (deposited: Int, withdrawn: Int) {
        transactions
            .filter { $0.player?.id == player.id }
            .reduce((deposited: 0, withdrawn: 0)) { result, entry in
                switch entry.type {
                case .deposit:
                    return (result.deposited + entry.amount, result.withdrawn)
                case .withdrawal:
                    return (result.deposited, result.withdrawn + entry.amount)
                }
            }
    }

    /// Вычисляет сумму, которую игрок должен банку.
    /// Возвращает положительное значение только для проигравших игроков, которые ещё не внесли полную сумму.
    func amountOwedToBank(for player: Player) -> Int {
        guard !player.inGame else { return 0 }

        // Если банк что-то должен игроку, то игрок ничего не должен банку
        let bankOwes = amountOwedByBank(for: player)
        if bankOwes > 0 { return 0 }

        let profit = player.cashOut - player.buyIn
        let profitInCash = profit * session.chipsToCashRatio
        let (deposited, withdrawn) = contributions(for: player)
        let netContribution = deposited - withdrawn

        // Игрок должен = abs(убыток в деньгах) - уже внесённое
        // Если игрок проиграл 50₽ и внёс 30₽ → должен 20₽
        // Если игрок проиграл 50₽ и внёс 100₽ → должен 0₽ (переплата учтена в amountOwedByBank)
        let playerOwes = -profitInCash - netContribution
        return max(playerOwes, 0)
    }

    /// Игроки, которые должны банку
    var playersOwingBank: [Player] {
        session.players
            .filter { amountOwedToBank(for: $0) > 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Общая сумма, которую банк должен всем игрокам (выигравшие + переплатившие)
    var totalOwedByBank: Int {
        session.players.reduce(0) { $0 + amountOwedByBank(for: $1) }
    }

    /// Вычисляет сумму, которую банк должен игроку.
    /// Включает выигрыш игрока (profit > 0) И переплаты (deposited > expected debt).
    func amountOwedByBank(for player: Player) -> Int {
        guard !player.inGame else { return 0 }

        let profit = player.cashOut - player.buyIn  // Может быть положительным или отрицательным
        let profitInCash = profit * session.chipsToCashRatio
        let (deposited, withdrawn) = contributions(for: player)
        let netContribution = deposited - withdrawn

        // Банк должен = профит в деньгах + внесённое игроком - выданное
        // Если игрок выиграл 100₽ и ничего не внёс → банк должен 100₽
        // Если игрок выиграл 100₽ и внёс 5₽ → банк должен 105₽ (выигрыш + депозит)
        // Если игрок проиграл 50₽ но внёс 100₽ → банк должен 50₽ (переплата)
        // Если игрок проиграл 50₽ и внёс 30₽ → банк должен 0₽ (ещё не расплатился)
        let bankOwes = profitInCash + netContribution
        return max(bankOwes, 0)
    }

    /// Список игроков, кому банк должен деньги (выигравшие + переплатившие)
    var playersOwedByBank: [Player] {
        session.players
            .filter { amountOwedByBank(for: $0) > 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }


}
