import Foundation

protocol SettlementProtocol {
    func calculate(for session: Session) -> SettlementResult
    func calculateWithBank(for session: Session) -> EnhancedSettlementResult
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
            let netChips = cashOut - buyIn
            let netCash = netChips * session.chipsToCashRatio
            balances.append(
                PlayerBalance(
                    player: player,
                    buyIn: buyIn,
                    cashOut: cashOut,
                    netChips: netChips,
                    netCash: netCash
                )
            )
        }

        let transfers = greedyTransfers(from: balances, chipToCashRatio: session.chipsToCashRatio)

        return SettlementResult(balances: balances, transfers: transfers)
    }

    /// Выполняет расчёт балансов и переводов с учётом операций банка.
    ///
    /// Алгоритм учитывает все банковские операции (deposits и withdrawals):
    /// 1. Рассчитывает базовые балансы игроков из покерных результатов
    /// 2. Собирает net-contribution каждого игрока (deposited - withdrawn)
    /// 3. Корректирует балансы с учётом банковских операций
    /// 4. Собирает активные депозиты (положительные net-contributions)
    /// 5. Применяет жадный алгоритм для схлопывания оставшихся депозитов с выигрышами
    /// 6. Обрабатывает переплаты
    /// 7. Для остатков применяет стандартный жадный алгоритм player-to-player
    ///
    /// - Parameter session: Сессия с банком для расчёта.
    /// - Returns: Расширенная структура с балансами, банковскими и прямыми переводами.
    func calculateWithBank(for session: Session) -> EnhancedSettlementResult {
        // Шаг 1: Рассчитываем базовые балансы игроков
        var balances: [PlayerBalance] = []
        for player in session.players {
            let buyIn = player.buyIn
            let cashOut = player.cashOut
            let netChips = cashOut - buyIn
            let netCash = netChips * session.chipsToCashRatio
            balances.append(
                PlayerBalance(
                    player: player,
                    buyIn: buyIn,
                    cashOut: cashOut,
                    netChips: netChips,
                    netCash: netCash
                )
            )
        }

        // Если банка нет, возвращаем стандартный расчёт без банковских переводов
        guard let bank = session.bank else {
            let transfers = greedyTransfers(from: balances, chipToCashRatio: session.chipsToCashRatio)
            return EnhancedSettlementResult(
                balances: balances,
                bankTransfers: [],
                playerTransfers: transfers
            )
        }

        // Шаг 2: Собираем net-contribution каждого игрока (deposited - withdrawn)
        var playerNetContributions: [UUID: Int] = [:]
        for player in session.players {
            let (deposited, withdrawn) = bank.contributions(for: player)
            let netContribution = deposited - withdrawn
            playerNetContributions[player.id] = netContribution
        }

        // Шаг 3: Корректируем балансы с учётом банковских операций
        // netContribution = deposited - withdrawn
        // Если netContribution < 0: игрок получил больше чем внёс (уже получил выплату)
        // Если netContribution > 0: игрок внёс больше чем получил (активный депозит)
        var creditors = balances
            .compactMap { balance -> (Player, Int)? in
                let netContribution = playerNetContributions[balance.player.id] ?? 0
                // Скорректированный выигрыш = покерный выигрыш + net contribution
                // Если withdrawn > deposited (negative netContribution), это УВЕЛИЧИВАЕТ выигрыш
                // Пример: выиграл 80, получил из банка 80 (netContribution = -80) → adjustedWin = 80 + (-80) = 0
                let adjustedWin = balance.netCash + netContribution
                return adjustedWin > 0 ? (balance.player, adjustedWin) : nil
            }
            .sorted { $0.1 > $1.1 } // по убыванию

        var debtors = balances
            .compactMap { balance -> (Player, Int)? in
                let netContribution = playerNetContributions[balance.player.id] ?? 0
                // Скорректированный долг = покерный долг - net contribution
                // Если deposited > withdrawn (positive netContribution), это УМЕНЬШАЕТ долг
                // Пример: проиграл 100, внёс в банк 100 (netContribution = 100) → adjustedDebt = 100 - 100 = 0 ✅
                let adjustedDebt = -balance.netCash - netContribution
                return adjustedDebt > 0 ? (balance.player, adjustedDebt) : nil
            }
            .sorted { $0.1 > $1.1 } // по убыванию

        // Шаг 4: Собираем активные депозиты (положительные net-contribution)
        var playerDeposits: [(player: Player, netDeposit: Int)] = []
        for player in session.players {
            let netContribution = playerNetContributions[player.id] ?? 0
            if netContribution > 0 {
                playerDeposits.append((player: player, netDeposit: netContribution))
            }
        }

        // Сортируем депозиты по убыванию для жадного алгоритма
        playerDeposits.sort { $0.netDeposit > $1.netDeposit }

        var bankTransfers: [BankTransfer] = []

        // Шаг 5: Применяем жадный алгоритм для схлопывания оставшихся депозитов с winners
        var depositIndex = 0
        var creditorIndex = 0

        while depositIndex < playerDeposits.count && creditorIndex < creditors.count {
            let (_, depositAmount) = playerDeposits[depositIndex]
            let (winner, winnerAmount) = creditors[creditorIndex]

            let transferAmount = min(depositAmount, winnerAmount)

            if transferAmount > 0 {
                // Создаём перевод из банка winner'у
                bankTransfers.append(BankTransfer(to: winner, amount: transferAmount))
            }

            let remainingDeposit = depositAmount - transferAmount
            let remainingWin = winnerAmount - transferAmount

            // Обновляем остатки
            playerDeposits[depositIndex].netDeposit = remainingDeposit
            creditors[creditorIndex].1 = remainingWin

            if remainingDeposit == 0 { depositIndex += 1 }
            if remainingWin == 0 { creditorIndex += 1 }
        }

        // Шаг 6: Обрабатываем переплаты (депозиты больше долга)
        // Если у игрока остался депозит, но он не должен (или выиграл), банк должен ему вернуть
        for depositIdx in depositIndex..<playerDeposits.count {
            let (depositor, remainingDeposit) = playerDeposits[depositIdx]
            if remainingDeposit > 0 {
                // Проверяем, есть ли у него долг
                if let debtorIdx = debtors.firstIndex(where: { $0.0.id == depositor.id }) {
                    let debt = debtors[debtorIdx].1
                    if debt > 0 {
                        // У него ещё есть долг, применим в следующей фазе
                        continue
                    }
                }
                // Переплата - банк должен вернуть
                bankTransfers.append(BankTransfer(to: depositor, amount: remainingDeposit))
            }
        }

        // Шаг 7: Рассчитываем оставшиеся прямые переводы player-to-player
        // Убираем игроков с нулевыми остатками
        creditors = creditors.filter { $0.1 > 0 }
        debtors = debtors.filter { $0.1 > 0 }

        var playerTransfers: [TransferProposal] = []
        var i = 0
        var j = 0

        while i < creditors.count && j < debtors.count {
            let (credPlayer, credAmt) = creditors[i]
            let (debtPlayer, debtAmt) = debtors[j]
            let pay = min(credAmt, debtAmt)

            if pay > 0 {
                playerTransfers.append(TransferProposal(from: debtPlayer, to: credPlayer, amount: pay))
            }

            let newCred = credAmt - pay
            let newDebt = debtAmt - pay

            creditors[i].1 = newCred
            debtors[j].1 = newDebt

            if newCred == 0 { i += 1 }
            if newDebt == 0 { j += 1 }
        }

        return EnhancedSettlementResult(
            balances: balances,
            bankTransfers: bankTransfers,
            playerTransfers: playerTransfers
        )
    }

    /// Жадный алгоритм, сопоставляющий игроков с положительным и отрицательным результатом.
    /// Переводы формируются так, чтобы максимально быстро обнулить долги,
    /// при этом каждый перевод идёт от текущего должника к текущему кредитору.
    /// Все переводы в РУБЛЯХ.
    private func greedyTransfers(from balances: [PlayerBalance], chipToCashRatio: Int) -> [TransferProposal] {
        var creditors = balances
            .filter { $0.netCash > 0 }
            .map { ($0.player, $0.netCash) }
            .sorted { $0.1 > $1.1 } // по убыванию

        var debtors = balances
            .filter { $0.netCash < 0 }
            .map { ($0.player, -$0.netCash) } // величина долга как положительная
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
    /// Совокупный buy-in (закупка + докупки) в фишках.
    let buyIn: Int
    /// Совокупный cash-out в фишках.
    let cashOut: Int
    /// Итоговый результат игрока в фишках (положительный — выигрыш, отрицательный — проигрыш).
    let netChips: Int
    /// Итоговый результат игрока в рублях (netChips × chipToCashRatio).
    let netCash: Int
}

/// Предложение перевода между двумя игроками, полученное после рассчёта.
/// Сумма перевода указана в РУБЛЯХ (cash), а не в фишках.
struct TransferProposal {
    let from: Player
    let to: Player
    let amount: Int  // В рублях (cash)
}

/// Перевод из банка игроку (выплата выигрыша или возврат переплаты).
struct BankTransfer {
    let to: Player
    let amount: Int  // В рублях (cash)
}

/// Совокупный результат работы калькулятора: балансы и список переводов.
struct SettlementResult {
    let balances: [PlayerBalance]
    let transfers: [TransferProposal]
}

/// Расширенный результат работы калькулятора с учётом банка.
struct EnhancedSettlementResult {
    let balances: [PlayerBalance]
    let bankTransfers: [BankTransfer]
    let playerTransfers: [TransferProposal]
}
