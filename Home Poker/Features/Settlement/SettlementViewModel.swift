import Foundation
import Observation

@Observable
final class SettlementViewModel {
    var balances: [PlayerBalance]
    var transfers: [TransferProposal]
    
    // Базовый инициализатор (может пригодиться в тестах/превью)
    init(balances: [PlayerBalance] = [], transfers: [TransferProposal] = []) {
        self.balances = balances
        self.transfers = transfers
    }
    
    // Удобный инициализатор из Session
    convenience init(session: Session) {
        self.init()
        calculate(for: session)
    }
    
    // Пересчет на основе текущего состояния сессии
    func calculate(for session: Session) {
        let result = SettlementCalculator.calculate(for: session)
        self.balances = result.balances
        self.transfers = result.transfers
    }
}
