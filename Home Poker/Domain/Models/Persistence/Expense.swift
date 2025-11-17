import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID = UUID()

    /// Общая сумма расхода (в рублях)
    var amount: Int

    /// Описание расхода
    var note: String

    /// Дата создания расхода
    var createdAt: Date

    /// Сумма, оплаченная из рейка (в рублях)
    var paidFromRake: Int

    /// Сумма, оплаченная из банка (в рублях)
    var paidFromBank: Int

    /// Плательщик расхода (опционально)
    /// Если указан - этому игроку должны вернуться деньги при settlement
    @Relationship(deleteRule: .nullify) var payer: Player?

    /// Распределение расхода между игроками
    /// Каждый ExpenseDistribution указывает, сколько должен заплатить конкретный игрок
    @Relationship(deleteRule: .cascade) var distributions: [ExpenseDistribution] = []

    init(amount: Int, note: String, createdAt: Date = Date(), payer: Player? = nil, paidFromRake: Int = 0, paidFromBank: Int = 0) {
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
        self.payer = payer
        self.paidFromRake = paidFromRake
        self.paidFromBank = paidFromBank
    }

    /// Общая сумма распределенного расхода
    var totalDistributed: Int {
        distributions.reduce(0) { $0 + $1.amount }
    }

    /// Проверка, полностью ли распределен расход
    /// Расход считается полностью распределенным, если:
    /// - Сумма distributions (доли игроков) + paidFromRake (покрыто из рейка) равна amount
    /// Это учитывает случаи, когда расход полностью или частично оплачен из рейка
    var isFullyDistributed: Bool {
        totalDistributed + paidFromRake == amount
    }

    /// Проверка, полностью ли оплачен расход
    /// Расход считается полностью оплаченным (закрытым), если:
    /// - paidFromBank покрывает весь amount (физическая оплата)
    /// paidFromRake не учитывается, т.к. это распределение ответственности, а не оплата
    var isFullyPaid: Bool {
        paidFromBank >= amount
    }
}

