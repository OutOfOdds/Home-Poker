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
    
    // MARK: - Игрок

    // Добавляем игрока 
    func addPlayer(name: String, buyIn: Int, to session: Session) throws {
        let trimmedName = try normalizePlayerName(name)
        try validatePositiveAmount(buyIn)
        
        let player = Player(name: trimmedName, inGame: true)
        let transaction = PlayerTransaction(type: .buyIn, amount: buyIn, player: player)
        player.transactions.append(transaction)
        session.players.append(player)
    }
    
    // Добавить игроку денег
    func addOn(player: Player, amount: Int) throws {
        try validatePositiveAmount(amount)
        let transaction = PlayerTransaction(type: .addOn, amount: amount, player: player)
        player.transactions.append(transaction)
    }
    
    // Игрок встал из за стола/завершил сессию
    func cashOut(player: Player, amount: Int, in session: Session) throws {
        try validateNonNegativeAmount(amount)
        guard amount <= session.bankInGame else {
            throw SessionServiceError.insufficientBank
        }
        
        let transaction = PlayerTransaction(type: .cashOut, amount: amount, player: player)
        player.transactions.append(transaction)
        player.inGame = false
    }

    // Вернуть игрока в игру после завершения
    func returnToGame(player: Player) {
        player.inGame = true
    }
    
    func removePlayer(_ player: Player, from session: Session) {
        session.players.removeAll { $0.id == player.id }
    }
    
    // MARK: - Расходы
    // Добавить расход (прим.: диллер, аренда комнаты и т.п)
    func addExpense(note: String, amount: Int, payer: Player?, to session: Session, createdAt: Date = Date()) throws {
        try validatePositiveAmount(amount)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(amount: amount, note: trimmedNote, createdAt: createdAt, payer: payer)
        session.expenses.append(expense)
    }
    
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        let ids = expenses.map { $0.id }
        session.expenses.removeAll { ids.contains($0.id) }
    }
    
    // MARK: - Настройки сессии
    func updateBlinds(for session: Session, small: Int, big: Int, ante: Int) throws {
        guard small > 0, big > 0, small <= big else {
            throw SessionServiceError.invalidBlinds
        }
        
        session.smallBlind = small
        session.bigBlind = big
        session.ante = max(0, ante)
    }

    // MARK: - Вспомогательные методы
    
    private func normalizePlayerName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SessionServiceError.emptyPlayerName }
        return trimmed
    }
    
    private func validatePositiveAmount(_ amount: Int) throws {
        guard amount > 0 else { throw SessionServiceError.invalidAmount }
    }
    
    private func validateNonNegativeAmount(_ amount: Int) throws {
        guard amount >= 0 else { throw SessionServiceError.invalidAmount }
    }
}
