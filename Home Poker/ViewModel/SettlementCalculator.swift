import Foundation

// MARK: - Result types

struct PlayerBalance {
    let player: Player
    let buyIn: Int
    let cashOut: Int
    let net: Int
}

struct TransferProposal {
    let from: Player
    let to: Player
    let amount: Int
}

struct SettlementResult {
    let balances: [PlayerBalance]
    let transfers: [TransferProposal]
}

// MARK: - Calculator

enum SettlementCalculator {
    
    // Простая калькуляция только по покерным результатам
    static func calculate(for session: Session) -> SettlementResult {
        // 1) Балансы по каждому игроку
        var balances: [PlayerBalance] = []
        for player in session.players {
            let buyIn = player.buyIn
            let cashOut = player.cashOut
            let net = cashOut - buyIn
            balances.append(PlayerBalance(player: player,
                                          buyIn: buyIn,
                                          cashOut: cashOut,
                                          net: net))
        }
        
        // 2) Генерация переводов (жадный алгоритм)
        let transfers = greedyTransfers(from: balances)
        
        return SettlementResult(balances: balances, transfers: transfers)
    }
}

// MARK: - Helpers

// Жадное сопоставление кредиторов и должников
private func greedyTransfers(from balances: [PlayerBalance]) -> [TransferProposal] {
    var creditors = balances
        .filter { $0.net > 0 }
        .map { ($0.player, $0.net) }
        .sorted { $0.1 > $1.1 } // по убыванию
    
    var debtors = balances
        .filter { $0.net < 0 }
        .map { ($0.player, -$0.net) } // величина долга как положительная
        .sorted { $0.1 > $1.1 } // по убыванию
    
    var transfers: [TransferProposal] = []
    var i = 0
    var j = 0
    
    while i < creditors.count && j < debtors.count {
        let (credPlayer, credAmt) = creditors[i]
        let (debtPlayer, debtAmt) = debtors[j]
        let pay = min(credAmt, debtAmt)
        if pay > 0 {
            transfers.append(TransferProposal(from: debtPlayer, to: credPlayer, amount: pay))
        }
        let newCred = credAmt - pay
        let newDebt = debtAmt - pay
        
        // Обновляем текущие остатки
        creditors[i].1 = newCred
        debtors[j].1 = newDebt
        
        if newCred == 0 { i += 1 }
        if newDebt == 0 { j += 1 }
    }
    return transfers
}
