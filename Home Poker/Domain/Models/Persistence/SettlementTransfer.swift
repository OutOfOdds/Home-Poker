import Foundation
import SwiftData

/// Представляет конкретный перевод в рамках расчета по сессии
/// Используется для отслеживания выполнения переводов между игроками или с банком
@Model
final class SettlementTransfer {
    @Attribute(.unique) var id: UUID = UUID()

    /// Сессия к которой относится перевод
    var session: Session

    /// Игрок отправляющий деньги (nil если перевод из банка)
    var fromPlayer: Player?

    /// Игрок получающий деньги (nil если перевод в банк)
    var toPlayer: Player?

    /// Сумма перевода в рублях
    var amount: Int

    /// Тип перевода
    var transferType: SettlementTransferType

    /// Статус выполнения перевода
    var isCompleted: Bool = false

    /// Дата и время когда перевод был отмечен как выполненный
    var completedAt: Date?

    /// Дополнительная заметка (например "Расход: доставка")
    var note: String?

    /// Дата создания записи о переводе
    var createdAt: Date = Date()

    init(
        session: Session,
        fromPlayer: Player?,
        toPlayer: Player?,
        amount: Int,
        transferType: SettlementTransferType,
        note: String? = nil
    ) {
        self.session = session
        self.fromPlayer = fromPlayer
        self.toPlayer = toPlayer
        self.amount = amount
        self.transferType = transferType
        self.note = note
    }
}

/// Типы переводов в рамках расчета
enum SettlementTransferType: String, Codable {
    /// Выдача из банка игроку
    case bankToPlayer = "Из кассы"

    /// Возврат от игрока в банк
    case playerToBank = "В кассу"

    /// Прямой перевод между игроками
    case playerToPlayer = "Между игроками"
}

// MARK: - Convenience Extensions

extension SettlementTransfer {
    /// Описание перевода для отображения в UI
    var displayDescription: String {
        switch transferType {
        case .bankToPlayer:
            return "Из кассы → \(toPlayer?.name ?? "?")"
        case .playerToBank:
            return "\(fromPlayer?.name ?? "?") → В кассу"
        case .playerToPlayer:
            return "\(fromPlayer?.name ?? "?") → \(toPlayer?.name ?? "?")"
        }
    }

    /// Помечает перевод как выполненный
    func markAsCompleted() {
        isCompleted = true
        completedAt = Date()
    }

    /// Снимает отметку о выполнении
    func markAsIncomplete() {
        isCompleted = false
        completedAt = nil
    }

    /// Переключает статус выполнения
    func toggleCompletion() {
        if isCompleted {
            markAsIncomplete()
        } else {
            markAsCompleted()
        }
    }
}
