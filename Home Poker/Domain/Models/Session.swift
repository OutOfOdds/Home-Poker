import Foundation
import SwiftData

@Model
class Session {
    @Attribute(.unique) var id: UUID = UUID()
    var startTime: Date
    var sessionTitle: String
    var location: String
    var gameType: GameType
    @Relationship(deleteRule: .cascade) var players: [Player] = []
    @Relationship(deleteRule: .cascade) var expenses: [Expense] = []
    @Relationship(deleteRule: .cascade) var bank: SessionBank?
    var status: SessionStatus
    var smallBlind: Int = 0
    var bigBlind: Int = 0
    var ante: Int = 0

    init(startTime: Date, location: String, gameType: GameType, status: SessionStatus, sessionTitle: String) {
        self.startTime = startTime
        self.location = location
        self.gameType = gameType
        self.status = status
        self.sessionTitle = sessionTitle
    }
    
    // Сумма всех закупов
    var totalBuyIns: Int {
        players.reduce(0) { $0 + $1.buyIn }
    }
    
    /// Деньги в игре: закуп - суммарная сумма вывода всех неактивных игроков (cashOut)
    var bankInGame: Int {
        totalBuyIns - bankWithdrawn
    }
    
    /// Сумма выведенных средств (по-прежнему, если надо для "Выведено")
    var bankWithdrawn: Int {
        players.filter { !$0.inGame }.reduce(0) { $0 + $1.cashOut }
    }
    
    var totalProfit: Int {
        players.reduce(0) { $0 + $1.profit }
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
    case finished = "Завершена"
}
