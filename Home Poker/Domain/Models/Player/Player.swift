import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var inGame: Bool = true

    // Финансовые операции теперь через транзакции
    @Relationship(deleteRule: .cascade)
    var transactions: [PlayerTransaction] = []

    var getsRakeback: Bool = false
    var rakeback: Int = 0

    init(name: String, inGame: Bool = true) {
        self.name = name
        self.inGame = inGame
    }

    /// Вычисляет финансовые показатели игрока за один проход по транзакциям.
    /// - Returns: Кортеж с buy-in (закупка + докупки) и cash-out (выводы).
    private func calculateFinancials() -> (buyIn: Int, cashOut: Int) {
        transactions.reduce((buyIn: 0, cashOut: 0)) { result, transaction in
            switch transaction.type {
            case .buyIn, .addOn:
                return (result.buyIn + transaction.amount, result.cashOut)
            case .cashOut:
                return (result.buyIn, result.cashOut + transaction.amount)
            }
        }
    }

    /// Суммарная закупка игрока (buy-in + все add-on).
    var buyIn: Int {
        calculateFinancials().buyIn
    }

    /// Суммарная сумма выводов игрока.
    var cashOut: Int {
        calculateFinancials().cashOut
    }

    /// Итоговая прибыль (или убыток) игрока.
    var profit: Int {
        let fin = calculateFinancials()
        return fin.cashOut - fin.buyIn
    }

    /// Текущий баланс игрока в игре (если inGame = true).
    var balance: Int {
        guard inGame else { return 0 }
        let fin = calculateFinancials()
        return fin.buyIn - fin.cashOut
    }

    /// Прибыль с учётом рейкбека.
    var profitAfterRakeback: Int { profit - rakeback }
}
