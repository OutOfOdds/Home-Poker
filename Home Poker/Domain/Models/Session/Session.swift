import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID = UUID()
    var startTime: Date
    var sessionTitle: String
    var location: String
    var gameType: GameType
    var chipsToCashRatio: Int = 1
    var status: SessionStatus
    var smallBlind: Int = 0
    var bigBlind: Int = 0
    var ante: Int = 0
    
    @Relationship(deleteRule: .cascade) var players: [Player] = []
    @Relationship(deleteRule: .cascade) var expenses: [Expense] = []
    @Relationship(deleteRule: .cascade) var bank: SessionBank?


    init(startTime: Date, location: String, gameType: GameType, status: SessionStatus, sessionTitle: String) {
        self.startTime = startTime
        self.location = location
        self.gameType = gameType
        self.status = status
        self.sessionTitle = sessionTitle
    }
    
    // Сумма всех фишек в игре
    var totalChips: Int {
        players.reduce(0) { $0 + $1.buyIn }
    }
    
    /// Фишки в игре: закуп - суммарная сумма вывода всех неактивных игроков (cashOut)
    var chipsInGame: Int {
        totalChips - chipsWithdrawn
    }
    
    /// Сумма выведенных фишек (по-прежнему, если надо для "Выведено")
    var chipsWithdrawn: Int {
        players.filter { !$0.inGame }.reduce(0) { $0 + $1.cashOut }
    }
    
    var activePlayers: [Player] {
        players.filter { $0.inGame }
    }
}

enum GameType: String, Codable {
    case NLHoldem = "NL Hold'em"
    case PLO4 = "PLO4"
}

enum SessionStatus: String, Codable {
    case active = "Активная"
    case awaitingForSettlements = "Ожидание расчетов"
    case finished = "Завершенная"
}
