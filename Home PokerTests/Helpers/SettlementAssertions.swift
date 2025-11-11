//
//  SettlementAssertions.swift
//  Home PokerTests
//
//  Helpers для проверки результатов Settlement расчётов
//

import Foundation
import Testing
@testable import Home_Poker

// MARK: - Проверки балансов

/// Проверяет баланс игрока по имени
/// - Parameters:
///   - result: Результат расчёта settlement
///   - playerName: Имя игрока
///   - expectedNetCash: Ожидаемый результат в рублях (положительный = выигрыш, отрицательный = проигрыш)
func assertBalance(
    _ result: SettlementResult,
    player playerName: String,
    netCash expectedNetCash: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let balance = result.balances.first(where: { $0.player.name == playerName }) else {
        Issue.record("Игрок '\(playerName)' не найден в балансах", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.netCash == expectedNetCash, "Ожидался баланс \(expectedNetCash)₽ для игрока \(playerName), получен \(balance.netCash)₽", sourceLocation: sourceLocation)
}

// MARK: - Проверки прямых переводов между игроками

/// Проверяет наличие прямого перевода между игроками
/// - Parameters:
///   - result: Результат расчёта settlement
///   - from: Имя игрока, который должен отправить деньги
///   - to: Имя игрока, который должен получить деньги
///   - amount: Ожидаемая сумма перевода в рублях
func assertPlayerTransfer(
    _ result: SettlementResult,
    from fromName: String,
    to toName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let transfer = result.playerTransfers.first { t in
        t.from.name == fromName && t.to.name == toName
    }

    guard let transfer = transfer else {
        Issue.record("Перевод от '\(fromName)' к '\(toName)' не найден", sourceLocation: sourceLocation)
        return
    }

    #expect(transfer.amount == expectedAmount, "Ожидалась сумма перевода \(expectedAmount)₽, получена \(transfer.amount)₽", sourceLocation: sourceLocation)
}

// MARK: - Проверки переводов из банка

/// Проверяет наличие перевода из банка игроку
/// - Parameters:
///   - result: Результат расчёта с банком
///   - to: Имя игрока, который должен получить деньги из банка
///   - amount: Ожидаемая сумма перевода в рублях
func assertBankTransfer(
    _ result: SettlementResult,
    to toName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let transfer = result.bankTransfers.first { t in
        t.to.name == toName && t.amount == expectedAmount
    }

    guard let transfer = transfer else {
        Issue.record("Перевод из банка игроку '\(toName)' на сумму \(expectedAmount)₽ не найден", sourceLocation: sourceLocation)
        return
    }

    #expect(transfer.amount == expectedAmount, "Ожидалась сумма перевода из банка \(expectedAmount)₽, получена \(transfer.amount)₽", sourceLocation: sourceLocation)
}

// MARK: - Проверки отсутствия переводов

/// Проверяет, что нет никаких прямых переводов между игроками
func assertNoPlayerTransfers(
    _ result: SettlementResult,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.playerTransfers.isEmpty, "Не должно быть прямых переводов, найдено \(result.playerTransfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет, что нет никаких переводов из банка
func assertNoBankTransfers(
    _ result: SettlementResult,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.bankTransfers.isEmpty, "Не должно быть переводов из банка, найдено \(result.bankTransfers.count)", sourceLocation: sourceLocation)
}

// MARK: - Проверки количества переводов

/// Проверяет общее количество прямых переводов
func assertPlayerTransferCount(
    _ result: SettlementResult,
    count expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.playerTransfers.count == expectedCount, "Ожидалось \(expectedCount) прямых переводов, получено \(result.playerTransfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет общее количество переводов из банка
func assertBankTransferCount(
    _ result: SettlementResult,
    count expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.bankTransfers.count == expectedCount, "Ожидалось \(expectedCount) переводов из банка, получено \(result.bankTransfers.count)", sourceLocation: sourceLocation)
}

// MARK: - Проверки рейкбека

/// Проверяет сумму рейкбека у игрока в балансе
/// - Parameters:
///   - result: Результат расчёта settlement
///   - playerName: Имя игрока
///   - expectedRakeback: Ожидаемая сумма рейкбека в рублях
func assertRakeback(
    _ result: SettlementResult,
    player playerName: String,
    amount expectedRakeback: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let balance = result.balances.first(where: { $0.player.name == playerName }) else {
        Issue.record("Игрок '\(playerName)' не найден в балансах", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.rakeback == expectedRakeback, "Ожидался рейкбек \(expectedRakeback)₽ для игрока \(playerName), получен \(balance.rakeback)₽", sourceLocation: sourceLocation)
}

// MARK: - Проверки расходов

/// Проверяет сумму оплаченных расходов игроком (как плательщиком)
/// - Parameters:
///   - result: Результат расчёта settlement
///   - playerName: Имя игрока
///   - expectedAmount: Ожидаемая сумма оплаченных расходов в рублях
func assertExpensePaid(
    _ result: SettlementResult,
    player playerName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let balance = result.balances.first(where: { $0.player.name == playerName }) else {
        Issue.record("Игрок '\(playerName)' не найден в балансах", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.expensePaid == expectedAmount, "Ожидалась оплата расходов \(expectedAmount)₽ для игрока \(playerName), получено \(balance.expensePaid)₽", sourceLocation: sourceLocation)
}

/// Проверяет долю игрока в расходах
/// - Parameters:
///   - result: Результат расчёта settlement
///   - playerName: Имя игрока
///   - expectedAmount: Ожидаемая доля игрока в расходах в рублях
func assertExpenseShare(
    _ result: SettlementResult,
    player playerName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let balance = result.balances.first(where: { $0.player.name == playerName }) else {
        Issue.record("Игрок '\(playerName)' не найден в балансах", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.expenseShare == expectedAmount, "Ожидалась доля в расходах \(expectedAmount)₽ для игрока \(playerName), получено \(balance.expenseShare)₽", sourceLocation: sourceLocation)
}
