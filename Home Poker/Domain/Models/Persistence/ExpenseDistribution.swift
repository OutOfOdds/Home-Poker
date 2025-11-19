import Foundation
import SwiftData

@Model
final class ExpenseDistribution {
    @Attribute(.unique) var id: UUID = UUID()
    @Relationship(deleteRule: .nullify) var player: Player
    @Relationship(deleteRule: .nullify) var expense: Expense
    
    var amount: Int
    
    init(amount: Int, player: Player, expense: Expense) {
        self.amount = amount
        self.player = player
        self.expense = expense
    }
}
