import SwiftUI
import Observation
import SwiftData

@Observable
final class SessionDetailViewModel {
    private let service: SessionService
    
    var alertMessage: String?
    
    init(service: SessionService = .shared) {
        self.service = service
    }
    
    // MARK: - Игроки
    
    /// Добавляет нового игрока в сессию, если buy-in введён корректно.
    /// Показывает сообщение об ошибке при неверном вводе.
    func addPlayer(to session: Session, name: String, buyIn: Int?) -> Bool {
        guard let buyIn, buyIn > 0 else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addPlayer(name: name, buyIn: buyIn, to: session)
        }
    }
    
    /// Регистрирует докупку игрока, валидируя введённую сумму.
    func addOn(for player: Player, in session: Session, amount: Int?) -> Bool {
        guard let amount, amount > 0 else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addOn(player: player, amount: amount, in: session)
        }
    }
    
    /// Завершает игру для игрока, добавляя cash-out транзакцию.
    /// Возвращает `false`, если сумма невалидна или операция завершилась ошибкой.
    func cashOut(session: Session, player: Player, amount: Int?) -> Bool {
        guard let amount, amount >= 0 else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.cashOut(player: player, amount: amount, in: session)
        }
    }
    
    /// Возвращает игрока обратно в статус `inGame = true`.
    func returnPlayerToGame(_ player: Player) {
        service.returnToGame(player: player)
    }
    
    /// Удаляет игрока из сессии, делегируя операцию сервису.
    func removePlayer(_ player: Player, from session: Session) {
        service.removePlayer(player, from: session)
    }
    
    /// Проверяет, является ли сумма корректной неотрицательной для ввода cash-out.
    func isValidCashOutAmount(_ amount: Int?) -> Bool {
        guard let amount else { return false }
        return amount >= 0
    }
    
    // MARK: - Расходы
    
    /// Добавляет расход в сессию и показывает alert при ошибке.
    func addExpense(to session: Session, note: String, amount: Int?, payer: Player? = nil) -> Bool {
        guard let amount, amount > 0 else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addExpense(note: note, amount: amount, payer: payer, to: session)
        }
    }
    
    /// Удаляет список расходов из сессии.
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        service.removeExpenses(expenses, from: session)
    }
    
    // MARK: - Настройки сессии
    
    /// Обновляет значения блайндов/анте в сессии, если ввод корректен.
    func updateBlinds(for session: Session, small: Int?, big: Int?, ante: Int?) -> Bool {
        guard let small, small > 0, let big, big > 0 else {
            setInvalidAmountError()
            return false
        }
        let anteValue = max(ante ?? 0, 0)
        
        return performServiceCall {
            try service.updateBlinds(for: session, small: small, big: big, ante: anteValue)
        }
    }
    
    // MARK: - Алерт
    
    /// Сбрасывает текущее сообщение об ошибке.
    func clearAlert() {
        alertMessage = nil
    }

    // MARK: - Session Bank
    
    /// Гарантирует наличие банка для сессии и возвращает его.
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
    
    /// Пытается закрыть сессионный банк. Alert покажется автоматически при ошибке.
    func closeBank(for session: Session) -> Bool {
        performServiceCall {
            try service.closeBank(for: session)
        }
    }
    
    /// Снова открывает банк после закрытия.
    func reopenBank(for session: Session) {
        service.reopenBank(for: session)
    }
    
    // MARK: - Helpers
    
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
    
    private func recordBankEntry(
        session: Session,
        player: Player,
        amount: Int?,
        note: String,
        type: SessionBankEntryType
    ) -> Bool {
        guard let amount, amount > 0 else {
            setInvalidAmountError()
            return false
        }
        let trimmedNote = note.nonEmptyTrimmed
        return performServiceCall {
            switch type {
            case .deposit:
                try service.recordDeposit(for: session, player: player, amount: amount, note: trimmedNote)
            case .withdrawal:
                try service.recordWithdrawal(for: session, player: player, amount: amount, note: trimmedNote)
            }
        }
    }
}
