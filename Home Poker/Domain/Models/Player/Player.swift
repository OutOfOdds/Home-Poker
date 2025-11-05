import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var inGame: Bool = true

    // Финансовые операции теперь через транзакции
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
    private func calculateFinancials() -> (buyIn: Int, cashOut: Int) {
        transactions.reduce((buyIn: 0, cashOut: 0)) { result, transaction in
            switch transaction.type {
            case .chipBuyIn, .chipAddOn:
                return (result.buyIn + transaction.chipAmount, result.cashOut)
            case .ChipCashOut:
                return (result.buyIn, result.cashOut + transaction.chipAmount)
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

    /// Начальный buy-in игрока (первая транзакция типа .buyIn).
    var initialBuyIn: Int {
        transactions.first(where: { $0.type == .chipBuyIn })?.chipAmount ?? 0
    }
}
