import Foundation
import SwiftData

@Model
final class ExpenseDistribution {
    @Attribute(.unique) var id: UUID = UUID()

    /// Доля игрока в расходе (в рублях)
    var amount: Int

    /// Игрок, который участвует в оплате расхода
    @Relationship(deleteRule: .nullify) var player: Player

    /// Родительский расход
    @Relationship(deleteRule: .nullify) var expense: Expense

    init(amount: Int, player: Player, expense: Expense) {
        self.amount = amount
        self.player = player
        self.expense = expense
    }
}
