//
//  SettlementAssertions.swift
//  Home PokerTests
//
//  Helpers для проверки результатов Settlement расчётов
//

import Foundation
import Testing
@testable import Home_Poker

// MARK: - Balance Assertions

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
        Issue.record("Player '\(playerName)' not found in balances", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.netCash == expectedNetCash, "Expected \(playerName) to have netCash=\(expectedNetCash), got \(balance.netCash)", sourceLocation: sourceLocation)
}

/// Проверяет балансы для расширенного результата (с банком)
func assertBalance(
    _ result: EnhancedSettlementResult,
    player playerName: String,
    netCash expectedNetCash: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let balance = result.balances.first(where: { $0.player.name == playerName }) else {
        Issue.record("Player '\(playerName)' not found in balances", sourceLocation: sourceLocation)
        return
    }
    #expect(balance.netCash == expectedNetCash, "Expected \(playerName) to have netCash=\(expectedNetCash), got \(balance.netCash)", sourceLocation: sourceLocation)
}

// MARK: - Player Transfer Assertions

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
    let transfer = result.transfers.first { t in
        t.from.name == fromName && t.to.name == toName
    }

    guard let transfer = transfer else {
        Issue.record("Transfer from '\(fromName)' to '\(toName)' not found", sourceLocation: sourceLocation)
        return
    }

    #expect(transfer.amount == expectedAmount, "Expected transfer amount \(expectedAmount), got \(transfer.amount)", sourceLocation: sourceLocation)
}

/// Проверяет наличие прямого перевода для расширенного результата
func assertPlayerTransfer(
    _ result: EnhancedSettlementResult,
    from fromName: String,
    to toName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let transfer = result.playerTransfers.first { t in
        t.from.name == fromName && t.to.name == toName
    }

    guard let transfer = transfer else {
        Issue.record("Transfer from '\(fromName)' to '\(toName)' not found", sourceLocation: sourceLocation)
        return
    }

    #expect(transfer.amount == expectedAmount, "Expected transfer amount \(expectedAmount), got \(transfer.amount)", sourceLocation: sourceLocation)
}

// MARK: - Bank Transfer Assertions

/// Проверяет наличие перевода из банка игроку
/// - Parameters:
///   - result: Результат расчёта с банком
///   - to: Имя игрока, который должен получить деньги из банка
///   - amount: Ожидаемая сумма перевода в рублях
func assertBankTransfer(
    _ result: EnhancedSettlementResult,
    to toName: String,
    amount expectedAmount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let transfer = result.bankTransfers.first { t in
        t.to.name == toName
    }

    guard let transfer = transfer else {
        Issue.record("Bank transfer to '\(toName)' not found", sourceLocation: sourceLocation)
        return
    }

    #expect(transfer.amount == expectedAmount, "Expected bank transfer amount \(expectedAmount), got \(transfer.amount)", sourceLocation: sourceLocation)
}

// MARK: - No Transfers Assertions

/// Проверяет, что нет никаких прямых переводов между игроками
func assertNoPlayerTransfers(
    _ result: SettlementResult,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.transfers.isEmpty, "Expected no player transfers, found \(result.transfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет, что нет никаких прямых переводов для расширенного результата
func assertNoPlayerTransfers(
    _ result: EnhancedSettlementResult,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.playerTransfers.isEmpty, "Expected no player transfers, found \(result.playerTransfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет, что нет никаких переводов из банка
func assertNoBankTransfers(
    _ result: EnhancedSettlementResult,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.bankTransfers.isEmpty, "Expected no bank transfers, found \(result.bankTransfers.count)", sourceLocation: sourceLocation)
}

// MARK: - Count Assertions

/// Проверяет общее количество прямых переводов
func assertPlayerTransferCount(
    _ result: SettlementResult,
    count expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.transfers.count == expectedCount, "Expected \(expectedCount) transfers, got \(result.transfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет общее количество прямых переводов для расширенного результата
func assertPlayerTransferCount(
    _ result: EnhancedSettlementResult,
    count expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.playerTransfers.count == expectedCount, "Expected \(expectedCount) player transfers, got \(result.playerTransfers.count)", sourceLocation: sourceLocation)
}

/// Проверяет общее количество переводов из банка
func assertBankTransferCount(
    _ result: EnhancedSettlementResult,
    count expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(result.bankTransfers.count == expectedCount, "Expected \(expectedCount) bank transfers, got \(result.bankTransfers.count)", sourceLocation: sourceLocation)
}
