import Foundation
import SwiftData

enum SessionServiceError: LocalizedError {
    case insufficientBank
    
    var errorDescription: String? {
        switch self {
        case .insufficientBank:
            return "Нельзя вывести больше, чем осталось в банке."
        }
    }
}

final class SessionService {

    func cashOut(player: Player, amount: Int, in session: Session) throws {
        guard amount >= 0 else { return }
        guard amount <= session.bankInGame else {
            throw SessionServiceError.insufficientBank
        }

        let transaction = PlayerTransaction(type: .cashOut, amount: amount, player: player)
        player.transactions.append(transaction)
        player.inGame = false
    }
}
