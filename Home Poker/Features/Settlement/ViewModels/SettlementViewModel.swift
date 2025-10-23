import Foundation
import Observation

@Observable
final class SettlementViewModel {
    @ObservationIgnored private let service: SettlementProtocol
    var balances: [PlayerBalance]
    var transfers: [TransferProposal]
    
    // Базовый инициализатор (может пригодиться в тестах/превью)
    init(
        service: SettlementProtocol = SettlementService(),
        balances: [PlayerBalance] = [],
        transfers: [TransferProposal] = []
    ) {
        self.service = service
        self.balances = balances
        self.transfers = transfers
    }
    
    // Удобный инициализатор из Session
    convenience init(session: Session, service: SettlementProtocol = SettlementService()) {
        self.init(service: service)
        calculate(for: session)
    }
    
    // Пересчет на основе текущего состояния сессии
    func calculate(for session: Session) {
        let result = service.calculate(for: session)
        self.balances = result.balances
        self.transfers = result.transfers
    }
}
