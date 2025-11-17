import Foundation

protocol SettlementProtocol {
    func calculate(for session: Session) -> SettlementResult
}

struct SettlementService: SettlementProtocol {

    /// Выполняет расчёт балансов и переводов с учётом операций банка.
    ///
    /// ПРАВИЛЬНАЯ ЛОГИКА (без двойного учёта):
    /// 1. Рассчитывает базовые балансы игроков из покерных результатов (chip economy)
    /// 2. Применяет рейкбек к балансам (money economy)
    /// 3. Собирает net-contribution каждого игрока (deposited - withdrawn)
    /// 4. Собирает начальных победителей (netCash > 0) и депозиты (netContribution > 0)
    /// 5. РАСПРЕДЕЛЯЕТ депозиты победителям через банк + ЗАПОМИНАЕТ суммы
    /// 6. ФОРМИРУЕТ ОКОНЧАТЕЛЬНЫХ creditors с учётом полученных денег из банка
    /// 7. ФОРМИРУЕТ ОКОНЧАТЕЛЬНЫХ debtors с учётом отправленных денег через банк
    /// 8. Обрабатывает переплаты (возврат из банка)
    /// 9. Формирует прямые переводы player-to-player для оставшихся сумм
    ///
    /// Ключевое отличие от старой версии:
    /// - Старая: формировала creditors/debtors ДО распределения депозитов (prediction)
    /// - Новая: формирует creditors/debtors ПОСЛЕ распределения депозитов (fact)
    /// Это устраняет двойной учёт денег игроков с частичными депозитами.
    ///
    /// - Parameter session: Сессия для расчёта.
    /// - Returns: Структура с балансами, банковскими переводами и прямыми переводами между игроками.
    func calculate(for session: Session) -> SettlementResult {
        // ============================================================
        // ШАГ 1: CHIP ECONOMY
        // ============================================================
        // Рассчитываем покерные результаты каждого игрока в фишках:
        // netChips = cashOut - buyIn
        // Затем конвертируем в деньги: netCash = netChips × chipsToCashRatio
        var balances: [PlayerBalance] = []
        for player in session.players {
            let buyIn = player.chipBuyIn
            let cashOut = player.chipCashOut
            let netChips = cashOut - buyIn
            let netCash = netChips * session.chipsToCashRatio
            balances.append(
                PlayerBalance(
                    player: player,
                    buyIn: buyIn,
                    cashOut: cashOut,
                    netChips: netChips,
                    netCash: netCash,
                    rakeback: 0,
                    expensePaid: 0,
                    expenseShare: 0
                )
            )
        }

        // ============================================================
        // ШАГ 2: ПРИМЕНЕНИЕ РЕЙКБЕКА
        // ============================================================
        // Рейкбек добавляется к netCash ПЕРЕД всеми расчётами settlement.
        // Это часть базового баланса игрока, учитывается во всех дальнейших расчётах.
        //
        // Примеры:
        // - Игрок проиграл 50₽, получил 10₽ рейкбека → netCash = -40₽ (долг уменьшился)
        // - Игрок выиграл 30₽, получил 5₽ рейкбека → netCash = +35₽ (выигрыш увеличился)
        for i in balances.indices {
            if balances[i].player.getsRakeback && balances[i].player.rakeback > 0 {
                balances[i].rakeback = balances[i].player.rakeback
                balances[i].netCash += balances[i].player.rakeback
            }
        }

        // ============================================================
        // ШАГ 3: УЧЁТ РАСХОДОВ
        // ============================================================
        // Расходы работают следующим образом:
        // 1. Если игрок оплатил расход → expensePaid (он должен получить эти деньги обратно)
        // 2. Каждый игрок имеет свою долю в расходах → expenseShare (он должен заплатить)
        // 3. Влияние на netCash: +expensePaid (возврат) - expenseShare (оплата доли)
        //
        // Примеры:
        // - Игрок оплатил 1000₽, его доля 250₽ → netCash += 1000 - 250 = +750₽
        // - Игрок не платил, его доля 250₽ → netCash += 0 - 250 = -250₽
        // - Игрок оплатил 1000₽, не участвует в оплате → netCash += 1000₽
        for i in balances.indices {
            let playerId = balances[i].player.id

            // Подсчитываем, сколько игрок оплатил как плательщик
            let paid = session.expenses
                .filter { $0.payer?.id == playerId }
                .reduce(0) { $0 + $1.amount }

            // Подсчитываем долю игрока в расходах
            let share = session.expenses
                .flatMap { $0.distributions }
                .filter { $0.player.id == playerId }
                .reduce(0) { $0 + $1.amount }

            balances[i].expensePaid = paid
            balances[i].expenseShare = share

            // Применяем к netCash: возврат оплаченного минус доля
            balances[i].netCash += paid - share
        }

        // Если банка нет, возвращаем стандартный расчёт без банковских переводов
        guard let bank = session.bank else {
            let transfers = greedyTransfers(from: balances)
            return SettlementResult(
                balances: balances,
                bankTransfers: [],
                playerTransfers: transfers
            )
        }

        // ============================================================
        // ШАГ 3: СБОР NET-CONTRIBUTION
        // ============================================================
        // netContribution = deposited - withdrawn
        //
        // Интерпретация:
        // - netContribution > 0: игрок внёс больше, чем получил (активный депозит в банк)
        // - netContribution < 0: игрок получил больше, чем внёс (уже получил выплату из банка)
        // - netContribution = 0: игрок не взаимодействовал с банком
        var playerNetContributions: [UUID: Int] = [:]
        for player in session.players {
            let (deposited, withdrawn) = bank.contributions(for: player)
            let netContribution = deposited - withdrawn
            playerNetContributions[player.id] = netContribution
        }

        // ============================================================
        // ШАГ 3.5: ПРИМЕНЕНИЕ БАНКОВСКИХ ОПЕРАЦИЙ К netCash
        // ============================================================
        // Добавляем netContribution к netCash, чтобы учесть банковские операции
        // Это делает расчет идентичным financialResult
        for i in balances.indices {
            let netContribution = playerNetContributions[balances[i].player.id] ?? 0
            balances[i].netCash += netContribution
        }

        // ============================================================
        // ШАГ 4-5 (УПРОЩЕННЫЙ): РАСПРЕДЕЛЕНИЕ БАЛАНСА БАНКА
        // ============================================================
        // Простая логика: берем физический баланс банка и распределяем победителям
        // Не важно кто вносил деньги — банк это общий пул денег

        var bankTransfers: [BankTransfer] = []
        var amountReceivedFromBank: [UUID: Int] = [:]

        // Если есть деньги в банке — распределяем победителям
        if let bank = session.bank, bank.netBalance > 0 {
            var remainingInBank = bank.netBalance

            // Сортируем победителей по убыванию выигрыша
            let winners = balances
                .filter { $0.netCash > 0 }
                .sorted { $0.netCash > $1.netCash }

            for var winner in winners {
                if remainingInBank == 0 { break }

                // Платим победителю из банка (минимум из его выигрыша или остатка в банке)
                let paymentAmount = min(winner.netCash, remainingInBank)

                if paymentAmount > 0 {
                    bankTransfers.append(BankTransfer(to: winner.player, amount: paymentAmount))
                    amountReceivedFromBank[winner.player.id, default: 0] += paymentAmount

                    // Уменьшаем его требование (он уже получил из банка)
                    winner.netCash -= paymentAmount
                    remainingInBank -= paymentAmount
                }
            }
        }

        // ============================================================
        // ШАГ 6: ФОРМИРОВАНИЕ ОКОНЧАТЕЛЬНЫХ CREDITORS
        // ============================================================
        // adjustedWin = netCash - amountReceivedFromBank
        //
        // Логика: Если игрок выиграл 130₽ и получил 120₽ из банка,
        // то в прямых переводах он должен получить только 10₽ (остаток).
        //
        // Пример:
        // - Алексей выиграл 130₽, получил 120₽ из банка → adjustedWin = 10₽
        // - Борис выиграл 70₽, получил 20₽ из банка → adjustedWin = 50₽
        var creditors = balances
            .compactMap { balance -> (Player, Int)? in
                guard balance.netCash > 0 else { return nil }
                let received = amountReceivedFromBank[balance.player.id] ?? 0
                let adjustedWin = balance.netCash - received
                return adjustedWin > 0 ? (balance.player, adjustedWin) : nil
            }
            .sorted { $0.1 > $1.1 } // по убыванию

        // ============================================================
        // ШАГ 7: ФОРМИРОВАНИЕ ОКОНЧАТЕЛЬНЫХ DEBTORS
        // ============================================================
        // Должники: игроки с netCash < 0 (должны заплатить)
        // Просто берем их долг как есть — депозиты уже учтены в netCash
        var debtors = balances
            .compactMap { balance -> (Player, Int)? in
                guard balance.netCash < 0 else { return nil }
                return (balance.player, abs(balance.netCash))
            }
            .sorted { $0.1 > $1.1 } // по убыванию

        // ============================================================
        // ШАГ 8: ПРЯМЫЕ ПЕРЕВОДЫ PLAYER-TO-PLAYER
        // ============================================================
        // Для оставшихся сумм (после распределения через банк) применяем
        // жадный алгоритм прямых переводов между игроками.
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

            creditors[i].1 -= pay
            debtors[j].1 -= pay

            if creditors[i].1 == 0 { i += 1 }
            if debtors[j].1 == 0 { j += 1 }
        }

        return SettlementResult(
            balances: balances,
            bankTransfers: bankTransfers,
            playerTransfers: playerTransfers
        )
    }

    /// Вычисляет реальную переплату игрока в банк
    /// Переплата = когда игрок внёс больше своего долга (ПОСЛЕ применения рейкбека)
    ///
    /// Пример:
    /// - Игрок проиграл 1000₽ (netChips = -1000₽)
    /// - Получил 300₽ рейкбека
    /// - Долг ПОСЛЕ рейкбека: 1000 - 300 = 700₽
    /// - Внёс в банк: 1000₽
    /// - Переплата: 1000 - 700 = 300₽ → должен вернуться из банка
    private func calculateOverpayment(
        for player: Player,
        balance: PlayerBalance,
        deposited: Int
    ) -> Int {
        // Долг ПОСЛЕ применения рейкбека (это итоговый netCash, если он отрицательный)
        let debtAfterRakeback = abs(min(balance.netCash, 0))
        return max(deposited - debtAfterRakeback, 0)
    }

    /// Жадный алгоритм, сопоставляющий игроков с положительным и отрицательным результатом.
    /// Переводы формируются так, чтобы максимально быстро обнулить долги,
    /// при этом каждый перевод идёт от текущего должника к текущему кредитору.
    private func greedyTransfers(from balances: [PlayerBalance]) -> [TransferProposal] {
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
    var netCash: Int
    /// Рейкбек, полученный игроком (в рублях).
    var rakeback: Int
    /// Сумма расходов, оплаченных игроком (если он плательщик).
    var expensePaid: Int
    /// Доля игрока в общих расходах (сколько он должен за расходы).
    var expenseShare: Int
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

/// Результат работы калькулятора расчётов: балансы игроков, банковские переводы и прямые переводы.
struct SettlementResult {
    let balances: [PlayerBalance]
    let bankTransfers: [BankTransfer]
    let playerTransfers: [TransferProposal]
}
