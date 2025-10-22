import Foundation
import SwiftData

@Model
final class SessionBank {
    @Attribute(.unique) var id: UUID = UUID()
    @Relationship(inverse: \Session.bank) var session: Session
    @Relationship var manager: Player?
    @Relationship(deleteRule: .cascade) var entries: [SessionBankEntry] = []
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
        entries.reduce((deposited: 0, withdrawn: 0)) { result, entry in
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
        entries
            .filter { $0.player.id == player.id }
            .reduce((deposited: 0, withdrawn: 0)) { result, entry in
                switch entry.type {
                case .deposit:
                    return (result.deposited + entry.amount, result.withdrawn)
                case .withdrawal:
                    return (result.deposited, result.withdrawn + entry.amount)
                }
            }
    }

    func outstandingAmount(for player: Player) -> Int {
        guard !player.inGame else { return 0 }
        let expected = max(player.buyIn - player.cashOut, 0)
        let (deposited, _) = contributions(for: player)
        return max(expected - deposited, 0)
    }

    var debtors: [Player] {
        session.players
            .filter { outstandingAmount(for: $0) > 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
