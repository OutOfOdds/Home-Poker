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
    
    func addPlayer(to session: Session, name: String, buyInText: String) -> Bool {
        guard let buyIn = parsePositiveAmount(buyInText) else {
            setInvalidAmountError()
            return false
        }
        
        do {
            try service.addPlayer(name: name, buyIn: buyIn, to: session)
            return true
        } catch {
            setError(error)
            return false
        }
    }
    
    func addOn(for player: Player, amountText: String) -> Bool {
        guard let amount = parsePositiveAmount(amountText) else {
            setInvalidAmountError()
            return false
        }
        
        do {
            try service.addOn(player: player, amount: amount)
            return true
        } catch {
            setError(error)
            return false
        }
    }
    
    func cashOut(session: Session, player: Player, amountText: String) -> Bool {
        guard let amount = parseNonNegativeAmount(amountText) else {
            setInvalidAmountError()
            return false
        }
        
        do {
            try service.cashOut(player: player, amount: amount, in: session)
            return true
        } catch {
            setError(error)
            return false
        }
    }
    
    func returnPlayerToGame(_ player: Player) {
        service.returnToGame(player: player)
    }
    
    func isValidCashOutInput(_ text: String) -> Bool {
        parseNonNegativeAmount(text) != nil
    }
    
    // MARK: - Расходы
    
    func addExpense(to session: Session, note: String, amountText: String, payer: Player? = nil) -> Bool {
        guard let amount = parsePositiveAmount(amountText) else {
            setInvalidAmountError()
            return false
        }
        
        do {
            try service.addExpense(note: note, amount: amount, payer: payer, to: session)
            return true
        } catch {
            setError(error)
            return false
        }
    }
    
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        service.removeExpenses(expenses, from: session)
    }
    
    // MARK: - Настройки сессии
    
    func updateBlinds(for session: Session, smallText: String, bigText: String, anteText: String) -> Bool {
        guard
            let small = parsePositiveAmount(smallText),
            let big = parsePositiveAmount(bigText)
        else {
            setInvalidAmountError()
            return false
        }
        let ante = parseNonNegativeAmount(anteText) ?? 0
        
        do {
            try service.updateBlinds(for: session, small: small, big: big, ante: ante)
            return true
        } catch {
            setError(error)
            return false
        }
    }
    
    // MARK: - Алерт
    
    func clearAlert() {
        alertMessage = nil
    }
    
    // MARK: - Helpers
    
    private func parsePositiveAmount(_ text: String) -> Int? {
        guard let value = Int(text), value > 0 else { return nil }
        return value
    }
    
    private func parseNonNegativeAmount(_ text: String) -> Int? {
        guard let value = Int(text), value >= 0 else { return nil }
        return value
    }
    
    private func setInvalidAmountError() {
        alertMessage = SessionServiceError.invalidAmount.errorDescription
    }
    
    private func setError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? "Произошла ошибка. Попробуйте ещё раз."
    }
}
