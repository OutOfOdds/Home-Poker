import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var inGame: Bool = true

    @Relationship(deleteRule: .cascade)
    var transactions: [PlayerChipTransaction] = []

    @Relationship(deleteRule: .cascade)
    var sessionBankTransactions: [SessionBankTransaction] = []

    var getsRakeback: Bool = false
    var rakeback: Int = 0

    init(name: String, inGame: Bool = true) {
        self.name = name
        self.inGame = inGame
    }

    /// Вычисляет финансовые показатели игрока за один проход по транзакциям.
    /// - Returns: Кортеж с buy-in (закупка + докупки) и cash-out (выводы).
    private func calculateChips() -> (buyIn: Int, cashOut: Int) {
        transactions.reduce((buyIn: 0, cashOut: 0)) { result, transaction in
            switch transaction.type {
            case .chipBuyIn, .chipAddOn:
                return (result.buyIn + transaction.chipAmount, result.cashOut)
            case .сhipCashOut:
                return (result.buyIn, result.cashOut + transaction.chipAmount)
            }
        }
    }

    /// Суммарная закупка игрока (buy-in + все add-on).
    var chipBuyIn: Int {
        calculateChips().buyIn
    }

    /// Суммарная сумма выводов игрока.
    var chipCashOut: Int {
        calculateChips().cashOut
    }

    /// Итоговая прибыль (или убыток) игрока.
    var chipProfit: Int {
        let fin = calculateChips()
        return fin.cashOut - fin.buyIn
    }

    /// Начальный buy-in игрока (для того что бы предлагать шаблоны докупки).
    var initialBuyIn: Int {
        transactions.first(where: { $0.type == .chipBuyIn })?.chipAmount ?? 0
    }
}
