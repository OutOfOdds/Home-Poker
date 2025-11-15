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

    /// Рейк собранный с игры (в фишках)
    /// Это информационное поле, реальные деньги учитываются в SessionBank
    /// Пример: 300 фишек рейка → 300₽ будет записано как withdrawal в банк
    var rakeAmount: Int = 0

    /// Чаевые дилеру (в фишках)
    /// Это информационное поле, реальные деньги учитываются в SessionBank
    /// Пример: 200 фишек чаевых → 200₽ будет записано как withdrawal в банк
    var tipsAmount: Int = 0

    /// Сумма чаевых, оплаченных из банка (в рублях)
    var tipsPaidFromBank: Int = 0

    /// Список всех игроков в сессии
    /// При удалении сессии все игроки удаляются автоматически (cascade)
    @Relationship(deleteRule: .cascade) var players: [Player] = []

    /// Список расходов, связанных с сессией
    /// Пример: оплата аренды помещения, заказ еды
    @Relationship(deleteRule: .cascade) var expenses: [Expense] = []

    /// Банк сессии для отслеживания денежных потоков
    /// Опциональный - создаётся при необходимости
    @Relationship(deleteRule: .cascade) var bank: SessionBank?


    init(startTime: Date, location: String, gameType: GameType, status: SessionStatus, sessionTitle: String) {
        self.startTime = startTime
        self.location = location
        self.gameType = gameType
        self.status = status
        self.sessionTitle = sessionTitle
    }
    
    /// Общее количество закупленных фишек всеми игроками
    /// Включает первичные buy-in и все add-on
    ///
    /// **Пример:**
    /// - Вася закупился на 5000 фишек
    /// - Петя закупился на 3000 фишек, докупил 2000
    /// - totalChips = 5000 + 3000 + 2000 = 10000 фишек
    var totalChips: Int {
        players.reduce(0) { $0 + $1.chipBuyIn }
    }

    /// Количество фишек физически находящихся на столе
    /// Рассчитывается как: все закупки минус все обналичивания минус рейк и чаевые
    ///
    /// **Пример:**
    /// - Миша закупил 5000, обналичил 500 → на столе 4500
    /// - Миша вернулся, закупил 500 → на столе 5000
    /// - Миша обналичил 5500 → попытка вывести больше чем есть! (ошибка)
    /// - После завершения записали рейк 100 и чаевые 50 → на столе -150 (учтены как выведенные)
    ///
    /// **Важно:** Используется для валидации при cash-out и учета рейка/чаевых
    var chipsInGame: Int {
        totalChips - totalCashOut - rakeAmount - tipsAmount
    }

    /// Общая сумма всех обналиченных фишек всеми игроками
    /// Включает все cash-out транзакции (частичные и полные)
    ///
    /// **Пример:**
    /// - Вася вывел 1000 фишек (частично)
    /// - Петя вывел 4500 фишек (полностью завершил игру)
    /// - totalCashOut = 1000 + 4500 = 5500 фишек
    var totalCashOut: Int {
        players.reduce(0) { $0 + $1.chipCashOut }
    }

    /// Список активных игроков (находящихся в игре)
    /// Игрок считается активным если inGame = true
    ///
    /// **Пример:**
    /// - Вася играет (inGame = true)
    /// - Петя завершил игру (inGame = false)
    /// - activePlayers = [Вася]
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
