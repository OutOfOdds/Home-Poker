//
//  SessionBuilder.swift
//  Home PokerTests
//
//  Created for testing Settlement calculations
//

import Foundation
@testable import Home_Poker

final class SessionBuilder {
    private var chipsToCashRatio: Int = 1
    private var rakeAmount: Int = 0
    private var tipsAmount: Int = 0
    private var players: [PlayerData] = []
    private var hasBank: Bool = false
    private var bankTransactions: [BankTransactionData] = []
    private var rakebackDistributions: [RakebackData] = []
    private var expenses: [ExpenseData] = []

    private struct PlayerData {
        let name: String
        let buyIn: Int
        let cashOut: Int
        let inGame: Bool
    }

    private struct BankTransactionData {
        let playerName: String
        let type: SessionBankTransactionType
        let amount: Int
    }

    private struct RakebackData {
        let playerName: String
        let amount: Int
    }

    private struct ExpenseData {
        let amount: Int
        let note: String
        let payerName: String?
        let distributions: [(String, Int)]  // (playerName, amount)
    }

    /// Устанавливает коэффициент конвертации фишки → рубли
    func withChipRatio(_ ratio: Int) -> SessionBuilder {
        self.chipsToCashRatio = ratio
        return self
    }

    /// Устанавливает рейк в фишках
    func withRake(_ amount: Int) -> SessionBuilder {
        self.rakeAmount = amount
        return self
    }

    /// Устанавливает чаевые в фишках
    func withTips(_ amount: Int) -> SessionBuilder {
        self.tipsAmount = amount
        return self
    }

    /// Добавляет игрока в сессию
    /// - Parameters:
    ///   - name: Имя игрока
    ///   - buyIn: Закуп в фишках (сумма всех buy-in транзакций)
    ///   - cashOut: Вывод в фишках (сумма всех cash-out транзакций)
    ///   - inGame: Находится ли игрок в игре (по умолчанию false)
    func addPlayer(_ name: String, buyIn: Int, cashOut: Int, inGame: Bool = false) -> SessionBuilder {
        players.append(PlayerData(name: name, buyIn: buyIn, cashOut: cashOut, inGame: inGame))
        return self
    }

    /// Включает банк в сессии
    func withBank() -> SessionBuilder {
        self.hasBank = true
        return self
    }

    /// Добавляет депозит в банк от игрока
    /// - Parameters:
    ///   - player: Имя игрока
    ///   - amount: Сумма в рублях
    func addBankDeposit(player: String, amount: Int) -> SessionBuilder {
        bankTransactions.append(
            BankTransactionData(playerName: player, type: .deposit, amount: amount)
        )
        return self
    }

    /// Добавляет выдачу из банка игроку
    /// - Parameters:
    ///   - player: Имя игрока
    ///   - amount: Сумма в рублях
    func addBankWithdrawal(player: String, amount: Int) -> SessionBuilder {
        bankTransactions.append(
            BankTransactionData(playerName: player, type: .withdrawal, amount: amount)
        )
        return self
    }

    /// Добавляет распределение рейкбека игроку
    /// - Parameters:
    ///   - player: Имя игрока
    ///   - amount: Сумма рейкбека в рублях
    func addRakebackDistribution(player: String, amount: Int) -> SessionBuilder {
        rakebackDistributions.append(
            RakebackData(playerName: player, amount: amount)
        )
        return self
    }

    /// Добавляет расход с распределением
    /// - Parameters:
    ///   - amount: Общая сумма расхода
    ///   - note: Описание расхода
    ///   - payer: Имя плательщика (кто оплатил расход), может быть nil
    ///   - distributions: Массив кортежей (имя игрока, его доля в расходе)
    func addExpense(
        amount: Int,
        note: String,
        payer: String?,
        distributions: [(String, Int)]
    ) -> SessionBuilder {
        expenses.append(
            ExpenseData(
                amount: amount,
                note: note,
                payerName: payer,
                distributions: distributions
            )
        )
        return self
    }

    /// Создаёт сконфигурированную сессию
    func build() -> Session {
        let session = Session(
            startTime: Date(),
            location: "Test Location",
            gameType: .NLHoldem,
            status: .active,
            sessionTitle: "Test Session"
        )
        session.chipsToCashRatio = chipsToCashRatio
        session.rakeAmount = rakeAmount
        session.tipsAmount = tipsAmount

        // Создаём игроков с транзакциями
        var playerDict: [String: Player] = [:]
        for playerData in players {
            let player = Player(
                name: playerData.name,
                inGame: playerData.inGame
            )

            // Добавляем buy-in транзакцию
            if playerData.buyIn > 0 {
                let buyInTx = PlayerChipTransaction(
                    type: .chipBuyIn,
                    amount: playerData.buyIn,
                    player: player,
                    timestamp: Date()
                )
                player.transactions.append(buyInTx)
            }

            // Добавляем cash-out транзакцию
            if playerData.cashOut > 0 {
                let cashOutTx = PlayerChipTransaction(
                    type: .сhipCashOut,
                    amount: playerData.cashOut,
                    player: player,
                    timestamp: Date()
                )
                player.transactions.append(cashOutTx)
            }

            session.players.append(player)
            playerDict[playerData.name] = player
        }

        // Применяем распределение рейкбека
        for rakebackData in rakebackDistributions {
            guard let player = playerDict[rakebackData.playerName] else {
                fatalError("Player '\(rakebackData.playerName)' not found. Add player before adding rakeback.")
            }
            player.getsRakeback = true
            player.rakeback = rakebackData.amount
        }

        // Создаём банк если нужно
        if hasBank {
            let bank = SessionBank(
                session: session,
                expectedTotal: 0
            )
            session.bank = bank

            // Добавляем банковские транзакции
            for txData in bankTransactions {
                guard let player = playerDict[txData.playerName] else {
                    fatalError("Player '\(txData.playerName)' not found. Add player before adding bank transactions.")
                }

                let transaction = SessionBankTransaction(
                    amount: txData.amount,
                    type: txData.type,
                    player: player,
                    bank: bank,
                    createdAt: Date()
                )
                bank.transactions.append(transaction)
            }
        }

        // Создаём расходы
        for expenseData in expenses {
            // Находим плательщика если указан
            let payer = expenseData.payerName != nil ? playerDict[expenseData.payerName!] : nil

            // Создаём расход
            let expense = Expense(
                amount: expenseData.amount,
                note: expenseData.note,
                createdAt: Date(),
                payer: payer
            )

            // Добавляем распределения
            for (playerName, distributionAmount) in expenseData.distributions {
                guard let player = playerDict[playerName] else {
                    fatalError("Player '\(playerName)' not found in expense distribution. Add player before adding expense.")
                }

                let distribution = ExpenseDistribution(
                    amount: distributionAmount,
                    player: player,
                    expense: expense
                )
                expense.distributions.append(distribution)
            }

            session.expenses.append(expense)
        }

        return session
    }
}
