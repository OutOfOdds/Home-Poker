import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class GameModel {
    let context: ModelContext?

    init(context: ModelContext? = nil) {
        self.context = context
    }

    // MARK: - Редактирование реквизитов сессии

    func setStartTime(for session: Session, to date: Date) {
        session.startTime = date
        // Если у вас duration — хранимое поле, пересчитайте его здесь.
        // Если duration вычисляется из startTime/endTime — ничего делать не нужно.
    }

    func setLocation(for session: Session, to location: String) {
        session.location = location
    }
    
    func setGameType(for session: Session, to gameType: GameType) {
        session.gameType = gameType
    }

    // MARK: - Управление игроками

    func addExistingPlayer(_ player: Player, to session: Session) {
        // Не добавляем дубликаты по id
        if !session.players.contains(where: { $0.id == player.id }) {
            session.players.append(player)
        }
    }

    func removePlayer(_ player: Player, from session: Session) {
        // При необходимости добавьте валидацию: нельзя удалять, если есть невыведенный стек
        session.players.removeAll { $0.id == player.id }
    }

    func setPlayerActive(_ player: Player, in session: Session, active: Bool) {
        // Если нужна логика при деактивации (автокэш-аут), добавьте её здесь
        player.isActive = active
    }

    // MARK: - Денежные операции

    func addBuyIn(to player: Player, amount: Int) {
        guard amount > 0 else { return }
        player.buyIn += amount
        // Если агрегаты (totalBuyIns/bankInGame/...) — хранимые поля в Session,
        // можно централизованно пересчитывать их здесь.
    }

    func cashOut(player: Player, amount: Int) {
        guard amount >= 0 else { return }
        // При необходимости добавьте проверку: amount <= текущего стека игрока
        player.cashOut = amount
        player.isActive = false
    }


    // MARK: - Сохранение (опционально)

    func save() throws {
        try context?.save()
    }
}
