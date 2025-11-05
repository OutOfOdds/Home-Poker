import Foundation
import Observation

@Observable
final class SettlementViewModel {
    @ObservationIgnored private let service: SettlementProtocol
    var balances: [PlayerBalance]
    var bankTransfers: [BankTransfer]
    var transfers: [TransferProposal]

    // Базовый инициализатор (может пригодиться в тестах/превью)
    init(
        service: SettlementProtocol = SettlementService(),
        balances: [PlayerBalance] = [],
        bankTransfers: [BankTransfer] = [],
        transfers: [TransferProposal] = []
    ) {
        self.service = service
        self.balances = balances
        self.bankTransfers = bankTransfers
        self.transfers = transfers
    }

    // Удобный инициализатор из Session
    convenience init(session: Session, service: SettlementProtocol = SettlementService()) {
        self.init(service: service)
        calculate(for: session)
    }

    // Пересчет на основе текущего состояния сессии с учётом банка
    func calculate(for session: Session) {
        let result = service.calculateWithBank(for: session)
        self.balances = result.balances
        self.bankTransfers = result.bankTransfers
        self.transfers = result.playerTransfers
    }
}
