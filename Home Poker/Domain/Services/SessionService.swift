import Foundation
import SwiftData

enum SessionServiceError: LocalizedError {
    case insufficientBank
    case invalidAmount
    case emptyPlayerName
    case invalidBlinds
    
    var errorDescription: String? {
        switch self {
        case .insufficientBank:
            return "Нельзя вывести больше, чем осталось в банке игры."
        case .invalidAmount:
            return "Сумма должна быть больше нуля."
        case .emptyPlayerName:
            return "Введите имя игрока."
        case .invalidBlinds:
            return "Укажите корректные значения блайндов."
        }
    }
}

final class SessionService {
    
    static let shared = SessionService()
    
    // MARK: - Players
    
    func addPlayer(name: String, buyIn: Int, to session: Session) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw SessionServiceError.emptyPlayerName }
        guard buyIn > 0 else { throw SessionServiceError.invalidAmount }
        
        let player = Player(name: trimmedName, inGame: true)
        let transaction = PlayerTransaction(type: .buyIn, amount: buyIn, player: player)
        player.transactions.append(transaction)
        session.players.append(player)
    }
    
    func addOn(player: Player, amount: Int) throws {
        guard amount > 0 else { throw SessionServiceError.invalidAmount }
        let transaction = PlayerTransaction(type: .addOn, amount: amount, player: player)
        player.transactions.append(transaction)
    }
    
    func cashOut(player: Player, amount: Int, in session: Session) throws {
        guard amount >= 0 else { throw SessionServiceError.invalidAmount }
        guard amount <= session.bankInGame else {
            throw SessionServiceError.insufficientBank
        }
        
        let transaction = PlayerTransaction(type: .cashOut, amount: amount, player: player)
        player.transactions.append(transaction)
        player.inGame = false
    }
    
    func returnToGame(player: Player) {
        player.inGame = true
    }
    
    // MARK: - Expenses
    
    func addExpense(note: String, amount: Int, payer: Player?, to session: Session, createdAt: Date = Date()) throws {
        guard amount > 0 else { throw SessionServiceError.invalidAmount }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(amount: amount, note: trimmedNote, createdAt: createdAt, payer: payer)
        session.expenses.append(expense)
    }
    
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        let ids = expenses.map { $0.id }
        session.expenses.removeAll { ids.contains($0.id) }
    }
    
    // MARK: - Session Settings
    
    func updateBlinds(for session: Session, small: Int, big: Int, ante: Int) throws {
        guard small > 0, big > 0, small <= big else {
            throw SessionServiceError.invalidBlinds
        }
        
        session.smallBlind = small
        session.bigBlind = big
        session.ante = max(0, ante)
    }
}
