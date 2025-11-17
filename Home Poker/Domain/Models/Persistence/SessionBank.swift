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

    // MARK: - Резервы (рейк и чаевые)

    /// Сумма рейка зарезервированная в балансе банка (в деньгах)
    var reservedForRake: Int {
        session.rakeAmount * session.chipsToCashRatio
    }

    /// Сумма чаевых зарезервированная в балансе банка (в деньгах)
    var reservedForTips: Int {
        session.tipsAmount * session.chipsToCashRatio
    }

    /// Общая сумма зарезервированная под рейк и чаевые
    var totalReserved: Int {
        reservedForRake + reservedForTips
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
            case .withdrawal, .expensePayment, .tipPayment:
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

    /// Общая сумма организационных расходов (оплата расходов и чаевых)
    var totalOrganizationalWithdrawals: Int {
        transactions
            .filter { $0.type == .expensePayment || $0.type == .tipPayment }
            .reduce(0) { $0 + $1.amount }
    }

    func contributions(for player: Player) -> (deposited: Int, withdrawn: Int) {
        // Личные транзакции игрока
        let personal = transactions
            .filter { $0.player?.id == player.id }
            .reduce((deposited: 0, withdrawn: 0)) { result, entry in
                switch entry.type {
                case .deposit:
                    return (result.deposited + entry.amount, result.withdrawn)
                case .withdrawal, .expensePayment, .tipPayment:
                    return (result.deposited, result.withdrawn + entry.amount)
                }
            }

        // Организационные withdrawal (player == nil) - расходы, покрытые из резервов
        // Эти расходы НЕ должны вычитаться из contribution вкладчика,
        // т.к. они компенсируются из резервов (рейка/чаевых)
        // НО они физически были оплачены из кассы, поэтому учитываем их,
        // а потом компенсируем через coveredExpensesShare
        if personal.deposited > 0 {
            let organizationalWithdrawals = totalOrganizationalWithdrawals

            // Сумма организационных расходов, покрытых из резервов
            let expensesCoveredFromReserves = session.expenses
                .reduce(0) { $0 + min($1.paidFromBank, $1.paidFromRake) }
            let tipsCoveredFromReserves = min(session.tipsPaidFromBank, reservedForTips)
            let totalCoveredFromReserves = expensesCoveredFromReserves + tipsCoveredFromReserves

            // Организационные расходы, НЕ покрытые резервами (реальные траты из банка)
            let uncoveredOrgWithdrawals = max(organizationalWithdrawals - totalCoveredFromReserves, 0)

            if uncoveredOrgWithdrawals > 0 {
                let totalDeposits = totalDeposited
                if totalDeposits > 0 {
                    let playerShare = Double(personal.deposited) / Double(totalDeposits)
                    let playerOrgWithdrawal = Int(Double(uncoveredOrgWithdrawals) * playerShare)
                    return (personal.deposited, personal.withdrawn + playerOrgWithdrawal)
                }
            }
        }

        return personal
    }

    /// Вычисляет финансовый результат игрока с учетом покера, рейкбека, банковских операций и расходов.
    /// - Returns: Положительное значение = игрок в плюсе (банк должен), отрицательное = игрок в минусе (игрок должен)
    /// - Note: Формула: (cashOut - buyIn) × ratio + rakeback + deposits - withdrawals + expensesPaid - expensesShare + coveredExpenses
    func financialResult(for player: Player) -> Int {
        guard !player.inGame else { return 0 }

        // Покерный результат с рейкбеком
        let profit = player.chipCashOut - player.chipBuyIn
        let rakebackAdjustment = player.getsRakeback ? player.rakeback : 0
        let profitInCash = (profit * session.chipsToCashRatio) + rakebackAdjustment

        // Банковские операции
        let (deposited, withdrawn) = contributions(for: player)
        let netContribution = deposited - withdrawn

        // Расходы: если игрок заплатил больше своей доли, ему должны вернуть разницу
        let expensePaid = session.expenses
            .filter { $0.payer?.id == player.id }
            .reduce(0) { $0 + $1.amount }

        let expenseShare = session.expenses
            .flatMap { $0.distributions }
            .filter { $0.player.id == player.id }
            .reduce(0) { $0 + $1.amount }

        let expenseAdjustment = expensePaid - expenseShare

        // Финальный результат
        // Организационные расходы, покрытые из резервов, уже учтены в contributions
        return profitInCash + netContribution + expenseAdjustment
    }

    /// Игроки, которые должны банку (отрицательный финансовый результат)
    var playersOwingBank: [Player] {
        session.players
            .filter { financialResult(for: $0) < 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Список игроков, кому банк должен деньги (положительный финансовый результат)
    var playersOwedByBank: [Player] {
        session.players
            .filter { financialResult(for: $0) > 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Расходы из рейка

    /// Общая сумма расходов, оплаченных из рейка
    var totalExpensesPaidFromRake: Int {
        session.expenses.reduce(0) { $0 + $1.paidFromRake }
    }

    /// Доступная сумма рейка для оплаты расходов
    /// Рассчитывается как: зарезервированный рейк минус распределенный рейкбек минус уже оплаченные расходы
    var availableRakeForExpenses: Int {
        let distributed = session.players.filter { $0.getsRakeback }.reduce(0) { $0 + $1.rakeback }
        return max(reservedForRake - distributed - totalExpensesPaidFromRake, 0)
    }

    /// Организационный сбор (то что остается дому после рейкбека и оплаты расходов)
    var organizationalFee: Int {
        let distributed = session.players.filter { $0.getsRakeback }.reduce(0) { $0 + $1.rakeback }
        return max(reservedForRake - distributed - totalExpensesPaidFromRake, 0)
    }

}
