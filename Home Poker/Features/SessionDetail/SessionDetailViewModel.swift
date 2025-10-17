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
        guard let buyIn = parseAmount(buyInText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addPlayer(name: name, buyIn: buyIn, to: session)
        }
    }
    
    func addOn(for player: Player, amountText: String) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addOn(player: player, amount: amount)
        }
    }
    
    func cashOut(session: Session, player: Player, amountText: String) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .nonNegative) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.cashOut(player: player, amount: amount, in: session)
        }
    }
    
    func returnPlayerToGame(_ player: Player) {
        service.returnToGame(player: player)
    }
    
    func removePlayer(_ player: Player, from session: Session) {
        service.removePlayer(player, from: session)
    }
    
    func isValidCashOutInput(_ text: String) -> Bool {
        parseAmount(text, requirement: .nonNegative) != nil
    }
    
    // MARK: - Расходы
    
    func addExpense(to session: Session, note: String, amountText: String, payer: Player? = nil) -> Bool {
        guard let amount = parseAmount(amountText, requirement: .positive) else {
            setInvalidAmountError()
            return false
        }
        
        return performServiceCall {
            try service.addExpense(note: note, amount: amount, payer: payer, to: session)
        }
    }
    
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        service.removeExpenses(expenses, from: session)
    }
    
    // MARK: - Настройки сессии
    
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
    
    func clearAlert() {
        alertMessage = nil
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
}
