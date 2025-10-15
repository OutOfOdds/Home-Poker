import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class GameModel {

    // MARK: - Редактирование реквизитов сессии

    func setStartTime(for session: Session, to date: Date) {
        session.startTime = date
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
        player.inGame = active
    }

    // MARK: - Денежные операции

    func addBuyIn(to player: Player, amount: Int) {
        guard amount > 0 else { return }
        let tx = Transaction(type: .buyIn, amount: amount, player: player)
        player.transactions.append(tx)
    }

    func addOn(to player: Player, amount: Int) {
        guard amount > 0 else { return }
        let tx = Transaction(type: .addOn, amount: amount, player: player)
        player.transactions.append(tx)
    }

    func cashOut(player: Player, amount: Int) {
        guard amount >= 0 else { return }
        let tx = Transaction(type: .cashOut, amount: amount, player: player)
        player.transactions.append(tx)
        player.inGame = false
    }
}
