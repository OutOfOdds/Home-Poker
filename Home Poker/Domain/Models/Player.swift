import Foundation
import SwiftData

@Model
class Player {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var inGame: Bool = true

    // Финансовые операции теперь через транзакции
    @Relationship(deleteRule: .cascade, inverse: \PlayerTransaction.player)
    var transactions: [PlayerTransaction] = []

    var getsRakeback: Bool = false
    var rakeback: Int = 0

    init(name: String, inGame: Bool = true) {
        self.name = name
        self.inGame = inGame
    }

    // Суммы считаются на лету из транзакций
    var buyIn: Int {
        transactions.filter { $0.type == .buyIn || $0.type == .addOn }
            .map { $0.amount }
            .reduce(0, +)
    }
    var cashOut: Int {
        // Последний cashOut или 0
        transactions.filter { $0.type == .cashOut }.last?.amount ?? 0
    }
    var profit: Int { cashOut - buyIn }
    var balance: Int { inGame ? buyIn - cashOut : 0 }
    var profitAfterRakeback: Int { profit - rakeback }
}
