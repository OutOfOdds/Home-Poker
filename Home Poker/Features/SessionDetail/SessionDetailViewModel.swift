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
    func addPlayer(to session: Session, name: String, buyInText: String) -> Bool {
        guard let buyIn = parseAmount(buyInText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addPlayer(name: name, buyIn: buyIn, to: session)
        }
    }
    
    /// Регистрирует докупку игрока, валидируя введённую сумму.
    func addOn(for player: Player, in session: Session, amountText: String) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addOn(player: player, amount: amount, in: session)
        }
    }
    
    /// Завершает игру для игрока, добавляя cash-out транзакцию.
    /// Возвращает `false`, если сумма невалидна или операция завершилась ошибкой.
    func cashOut(session: Session, player: Player, amountText: String) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .nonNegative) else {
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
    
    /// Проверяет, является ли текст корректной неотрицательной суммой для ввода cash-out.
    func isValidCashOutInput(_ text: String) -> Bool {
        parseAmount(text, requirement: .nonNegative) != nil
    }
    
    // MARK: - Расходы
    
    /// Добавляет расход в сессию и показывает alert при ошибке.
    func addExpense(to session: Session, note: String, amountText: String, payer: Player? = nil) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .positive) else {
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
    func updateBlinds(for session: Session, smallText: String, bigText: String, anteText: String) -> Bool {
        guard
            let small = parseAmount(smallText, requirement: .positive),
            let big = parseAmount(bigText, requirement: .positive)
        else {
            setInvalidAmountError()
            return false
        }
        let ante = parseAmount(anteText, requirement: .nonNegative) ?? 0
        
        return performServiceCall {
            try service.updateBlinds(for: session, small: small, big: big, ante: ante)
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
    func recordBankDeposit(session: Session, player: Player, amountText: String, note: String) -> Bool {
        recordBankEntry(session: session, player: player, amountText: amountText, note: note, type: .deposit)
    }
    
    /// Фиксирует выдачу средств из банка игроку.
    func recordBankWithdrawal(session: Session, player: Player, amountText: String, note: String) -> Bool {
        recordBankEntry(session: session, player: player, amountText: amountText, note: note, type: .withdrawal)
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
    
    private enum AmountRequirement {
        case positive
        case nonNegative
    }
    
    private func parseAmount(_ text: String, requirement: AmountRequirement) -> Int? {
        guard let value = Int(text) else { return nil }
        switch requirement {
        case .positive:
            return value > 0 ? value : nil
        case .nonNegative:
            return value >= 0 ? value : nil
        }
    }
    
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
        amountText: String,
        note: String,
        type: SessionBankEntryType
    ) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return performServiceCall {
            switch type {
            case .deposit:
                try service.recordDeposit(for: session, player: player, amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)
            case .withdrawal:
                try service.recordWithdrawal(for: session, player: player, amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)
            }
        }
    }
}
