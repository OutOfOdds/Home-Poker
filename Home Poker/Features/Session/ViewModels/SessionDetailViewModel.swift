import SwiftUI
import Observation
import SwiftData

@Observable
final class SessionDetailViewModel {
    private let service: SessionServiceProtocol
    
    var alertMessage: String?
    
    init(service: SessionServiceProtocol = SessionService()) {
        self.service = service
    }
    // MARK: - Игроки

    /// Добавляет нового игрока в сессию, если buy-in введён корректно.
    /// Показывает сообщение об ошибке при неверном вводе.
    func addPlayer(to session: Session, name: String, buyIn: Int?) -> Bool {
        guard validateAmount(buyIn) else { return false }
        return performServiceCall {
            try service.addPlayer(name: name, buyIn: buyIn!, to: session)
        }
    }

    /// Регистрирует докупку игрока, валидируя введённую сумму.
    func addOn(for player: Player, in session: Session, amount: Int?) -> Bool {
        guard validateAmount(amount) else { return false }
        return performServiceCall {
            try service.addOn(player: player, amount: amount!, in: session)
        }
    }

    /// Завершает игру для игрока, добавляя cash-out транзакцию.
    /// Возвращает `false`, если сумма невалидна или операция завершилась ошибкой.
    func cashOut(session: Session, player: Player, amount: Int?) -> Bool {
        guard validateAmount(amount, allowZero: true) else { return false }
        return performServiceCall {
            try service.cashOut(player: player, amount: amount!, in: session)
        }
    }

    /// Возвращает игрока в игру с новой закупкой.
    /// Каждый возврат требует новой закупки, как в реальной покерной игре.
    /// - Parameters:
    ///   - player: Игрок, возвращающийся в игру.
    ///   - amount: Сумма новой закупки.
    ///   - session: Сессия, в которую возвращается игрок.
    /// - Returns: `true` если операция успешна, `false` при ошибке.
    func rebuyPlayer(_ player: Player, amount: Int?, in session: Session) -> Bool {
        guard validateAmount(amount) else { return false }
        return performServiceCall {
            try service.returnPlayerWithRebuy(player, amount: amount!, in: session)
        }
    }
    
    /// Удаляет игрока из сессии, делегируя операцию сервису.
    func removePlayer(_ player: Player, from session: Session) {
        service.removePlayer(player, from: session)
    }

    func removeTransaction(_ transaction: PlayerTransaction, from session: Session) {
        service.removeTransaction(transaction, from: session)
    }
    
    // MARK: - Расходы

    // Добавляет расход в сессию и показывает alert при ошибке.
    func addExpense(to session: Session, note: String, amount: Int?, payer: Player? = nil) -> Bool {
        guard validateAmount(amount) else { return false }
        return performServiceCall {
            try service.addExpense(note: note, amount: amount!, payer: payer, to: session, createdAt: Date())
        }
    }
    
    // Удаляет список расходов из сессии.
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        service.removeExpenses(expenses, from: session)
    }
    
    // MARK: - Настройки сессии
    
    // Обновляет значения блайндов/анте в сессии, если ввод корректен.
    func updateBlinds(for session: Session, small: Int?, big: Int?, ante: Int?) -> Bool {
        guard validateAmount(small), validateAmount(big) else { return false }
        let anteValue = max(ante ?? 0, 0)
        return performServiceCall {
            try service.updateBlinds(for: session, small: small!, big: big!, ante: anteValue)
        }
    }
    
    // MARK: - Алерт
    
    // Сбрасывает текущее сообщение об ошибке.
    func clearAlert() {
        alertMessage = nil
    }

    // MARK: - Session Bank
    
    // Гарантирует наличие банка для сессии и возвращает его.
    @discardableResult
    func ensureBank(for session: Session) -> SessionBank {
        return service.ensureBank(for: session)
    }
    
    /// Назначает игрока ответственным за сессионный банк.
    func setBankManager(_ player: Player?, for session: Session) {
        service.setBankManager(player, for: session)
    }
    
    /// Фиксирует взнос игрока в банк. Возвращает `false`, если сумма некорректна.
    func recordBankDeposit(session: Session, player: Player, amount: Int?, note: String) -> Bool {
        recordBankEntry(session: session, player: player, amount: amount, note: note, type: .deposit)
    }

    /// Фиксирует выдачу средств из банка игроку.
    func recordBankWithdrawal(session: Session, player: Player, amount: Int?, note: String) -> Bool {
        recordBankEntry(session: session, player: player, amount: amount, note: note, type: .withdrawal)
    }

    /// Универсальный метод записи банковской транзакции (внутренний).
    private func recordBankEntry(
        session: Session,
        player: Player,
        amount: Int?,
        note: String,
        type: SessionBankTransactionType
    ) -> Bool {
        guard validateAmount(amount) else { return false }
        let trimmedNote = note.nonEmptyTrimmed
        return performServiceCall {
            try service.recordBankTransaction(for: session, player: player, amount: amount!, note: trimmedNote, type: type)
        }
    }

    /// Удаляет транзакцию из банка. Возвращает `false` при ошибке (например, банк закрыт).
    func deleteBankTransaction(_ transaction: SessionBankTransaction, from session: Session) -> Bool {
        performServiceCall {
            try service.removeBankTransaction(transaction, from: session)
        }
    }

    /// Пытается закрыть сессионный банк. Alert покажется автоматически при ошибке.
    func closeBank(for session: Session) {
        performServiceCall {
            try service.closeBank(for: session)
        }
    }
    
    /// Снова открывает банк после закрытия.
    func reopenBank(for session: Session) {
        service.reopenBank(for: session)
    }
    
    // MARK: - Helpers

    /// Универсальный метод валидации суммы.
    /// - Parameters:
    ///   - amount: Опциональная сумма для проверки.
    ///   - allowZero: Разрешает ли значение 0 (по умолчанию `false`).
    /// - Returns: `true` если сумма валидна, иначе `false` (с установкой alert).
    private func validateAmount(_ amount: Int?, allowZero: Bool = false) -> Bool {
        guard let amount else {
            setInvalidAmountError()
            return false
        }
        let isValid = allowZero ? amount >= 0 : amount > 0
        if !isValid {
            setInvalidAmountError()
        }
        return isValid
    }

    @discardableResult
    private func performServiceCall(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    private func setInvalidAmountError() {
        alertMessage = SessionServiceError.invalidAmount.errorDescription
    }

    private func setError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? "Произошла ошибка. Попробуйте ещё раз."
    }
}
