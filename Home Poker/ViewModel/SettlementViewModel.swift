import Foundation

struct SettlementViewModel {
    let balances: [PlayerBalance]
    let transfers: [TransferProposal]
    
    init(session: Session) {
        let result = SettlementCalculator.calculate(for: session)
        self.balances = result.balances
        self.transfers = result.transfers
    }
}
