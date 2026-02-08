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

    /// Явный источник оплаты расхода
    var source: ExpenseSource?

    /// Плательщик расхода (опционально)
    /// Если указан - этому игроку должны вернуться деньги при settlement
    @Relationship(deleteRule: .nullify) var payer: Player?

    /// Распределение расхода между игроками
    /// Каждый ExpenseDistribution указывает, сколько должен заплатить конкретный игрок
    @Relationship(deleteRule: .cascade) var distributions: [ExpenseDistribution] = []

    init(
        amount: Int,
        note: String,
        createdAt: Date = Date(),
        payer: Player? = nil,
        paidFromRake: Int = 0,
        paidFromBank: Int = 0,
        source: ExpenseSource = .later
    ) {
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
        self.payer = payer
        self.paidFromRake = paidFromRake
        self.paidFromBank = paidFromBank
        self.source = source
    }

    /// Общая сумма распределенного расхода
    var totalDistributed: Int {
        distributions.reduce(0) { $0 + $1.amount }
    }

    /// Проверка, полностью ли распределен расход
    /// Для разных источников оплаты требования разные:
    /// - Рейк: распределение между игроками не требуется
    /// - Организаторы: либо без списания с игроков (0), либо полное списание (amount)
    /// - Игрок / Касса / Указать позже: ожидается полное распределение на игроков
    var isFullyDistributed: Bool {
        switch resolvedSource {
        case .rake:
            return paidFromRake >= amount
        case .organizers:
            return totalDistributed == 0 || totalDistributed == amount
        case .later, .player, .bank:
            return totalDistributed == amount
        }
    }

    /// Проверка, полностью ли оплачен расход
    /// Расход считается полностью оплаченным (закрытым), если:
    /// - paidFromBank покрывает весь amount (физическая оплата)
    /// paidFromRake не учитывается, т.к. это распределение ответственности, а не оплата
    var isFullyPaid: Bool {
        paidFromBank >= amount
    }

    /// Проверка, требует ли расход распределения
    /// Возвращает true, если для данного источника оплаты нужно распределение, но оно не завершено.
    var needsDistribution: Bool {
        switch distributionState {
        case .needsDistribution:
            return true
        case .notRequired, .distributed, .needsReview:
            return false
        }
    }

    var requiresReview: Bool {
        switch distributionState {
        case .needsReview:
            return true
        case .notRequired, .distributed, .needsDistribution:
            return false
        }
    }

    /// Источник оплаты с fallback для старых записей без явного `source`.
    var resolvedSource: ExpenseSource {
        if let source, source != .later {
            return source
        }

        if payer != nil {
            return .player
        }
        if paidFromBank > 0 {
            return .bank
        }
        if paidFromRake > 0 {
            return .rake
        }
        if !distributions.isEmpty {
            return .organizers
        }

        return .later
    }

    var distributionState: ExpenseDistributionState {
        if isInconsistent {
            return .needsReview
        }

        switch resolvedSource {
        case .rake:
            return .notRequired
        case .organizers:
            if totalDistributed == 0 {
                return .notRequired
            }
            return totalDistributed == amount ? .distributed : .needsReview
        case .later, .player, .bank:
            if totalDistributed == amount {
                return .distributed
            }
            if totalDistributed < amount {
                return .needsDistribution
            }
            return .needsReview
        }
    }

    var distributedPlayerCount: Int {
        Set(distributions.map(\.player.id)).count
    }

    var sourceStatusText: String {
        switch resolvedSource {
        case .later:
            return "Источник: указать позже"
        case .player:
            if let payer {
                return "Источник: игрок \(payer.name)"
            }
            return "Источник: игрок"
        case .bank:
            return paidFromBank > 0
                ? "Источник: касса \(paidFromBank.asCurrency())"
                : "Источник: касса"
        case .rake:
            return paidFromRake > 0
                ? "Источник: рейк \(paidFromRake.asCurrency())"
                : "Источник: рейк"
        case .organizers:
            if totalDistributed > 0 {
                return "Источник: организаторы (с вычетом)"
            }
            if paidFromRake > 0 {
                return "Источник: организаторы (без вычета, покрыто рейком)"
            }
            return "Источник: организаторы (без вычета)"
        }
    }

    var distributionStatusText: String {
        switch distributionState {
        case .notRequired:
            if resolvedSource == .organizers, totalDistributed == 0, paidFromRake > 0 {
                return "Распределение: не требуется, покрыто рейком \(paidFromRake.asCurrency())"
            }
            return "Распределение: не требуется"
        case .distributed:
            return "Распределение: списано с \(distributedPlayerCount) игроков"
        case .needsDistribution:
            if totalDistributed == 0 {
                return "Распределение: не задано"
            }
            let remaining = max(amount - totalDistributed, 0)
            return "Распределение: осталось \(remaining.asCurrency())"
        case .needsReview:
            return "Распределение: нужна проверка"
        }
    }

    private var isInconsistent: Bool {
        if totalDistributed > amount {
            return true
        }

        let activePaymentSignals = [payer != nil, paidFromBank > 0, paidFromRake > 0].filter { $0 }.count
        if activePaymentSignals > 1 {
            return true
        }

        switch resolvedSource {
        case .later:
            return false
        case .player:
            return payer == nil || paidFromBank > 0 || paidFromRake > 0
        case .bank:
            return paidFromBank <= 0 || payer != nil || paidFromRake > 0
        case .rake:
            return paidFromRake <= 0 || payer != nil || paidFromBank > 0 || totalDistributed > 0
        case .organizers:
            if payer != nil || paidFromBank > 0 {
                return true
            }
            if totalDistributed > 0 {
                return paidFromRake > 0
            }
            return paidFromRake < 0 || paidFromRake > amount
        }
    }
}

enum ExpenseSource: String, Codable, CaseIterable {
    case later
    case player
    case bank
    case rake
    case organizers
}

enum ExpenseDistributionState {
    case notRequired
    case distributed
    case needsDistribution
    case needsReview
}
