import Foundation

protocol SettlementProtocol {
    func calculate(for session: Session) -> SettlementResult
}

struct SettlementService: SettlementProtocol {
    
    /// Выполняет расчёт балансов и необходимых переводов по данным сессии.
    ///
    /// Алгоритм учитывает только покерные результаты (buy-in и cash-out):
    /// - Вычисляет агрегированные балансы для каждого игрока (`PlayerBalance`).
    /// - Формирует список переводов между должниками и кредиторами с помощью жадного алгоритма.
    ///
    /// Предполагается, что сессия завершена и у всех игроков корректно рассчитаны buy-in/cash-out.
    /// Операции с сессионным банком здесь не учитываются.
    ///
    /// - Parameter session: Сессия, для которой выполняется расчёт.
    /// - Returns: Структура с балансами игроков и предложениями переводов.
    func calculate(for session: Session) -> SettlementResult {
        var balances: [PlayerBalance] = []
        for player in session.players {
            let buyIn = player.buyIn
            let cashOut = player.cashOut
            let net = cashOut - buyIn
            balances.append(
                PlayerBalance(
                    player: player,
                    buyIn: buyIn,
                    cashOut: cashOut,
                    net: net
                )
            )
        }
        
        let transfers = greedyTransfers(from: balances)
        
        return SettlementResult(balances: balances, transfers: transfers)
    }
    
    /// Жадный алгоритм, сопоставляющий игроков с положительным и отрицательным результатом.
    /// Переводы формируются так, чтобы максимально быстро обнулить долги,
    /// при этом каждый перевод идёт от текущего должника к текущему кредитору.
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
}

/// Описывает агрегированное состояние игрока по итогам сессии.
struct PlayerBalance {
    /// Игрок, чьи результаты агрегированы.
    let player: Player
    /// Совокупный buy-in (закупка + докупки).
    let buyIn: Int
    /// Совокупный cash-out.
    let cashOut: Int
    /// Итоговый результат игрока (положительный — выигрыш, отрицательный — проигрыш).
    let net: Int
}

/// Предложение перевода между двумя игроками, полученное после рассчёта.
struct TransferProposal {
    let from: Player
    let to: Player
    let amount: Int
}

/// Совокупный результат работы калькулятора: балансы и список переводов.
struct SettlementResult {
    let balances: [PlayerBalance]
    let transfers: [TransferProposal]
}
