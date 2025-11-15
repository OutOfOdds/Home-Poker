//
//  SessionTransferDTO.swift
//  Home Poker
//
//  Created for session export/import functionality
//

import Foundation

// MARK: - Main Transfer DTO

/// Основная DTO структура для экспорта/импорта сессии
struct SessionTransferDTO: Codable {
    let id: UUID
    let sessionTitle: String
    let startTime: Date
    let location: String
    let gameType: String
    let chipsToCashRatio: Int
    let smallBlind: Int
    let bigBlind: Int
    let ante: Int
    let status: String
    let rakeAmount: Int
    let tipsAmount: Int
    let tipsPaidFromBank: Int

    let players: [PlayerTransferDTO]
    let bank: SessionBankTransferDTO?
    let expenses: [ExpenseTransferDTO]
    let metadata: TransferMetadata

    struct TransferMetadata: Codable {
        let formatVersion: String
        let exportDate: Date
        let appVersion: String
    }
}

// MARK: - Player DTOs

/// DTO для передачи данных игрока
struct PlayerTransferDTO: Codable {
    let id: UUID
    let name: String
    let inGame: Bool
    let getsRakeback: Bool
    let rakeback: Int
    let transactions: [PlayerChipTransactionTransferDTO]
}

/// DTO для передачи транзакций фишек игрока
struct PlayerChipTransactionTransferDTO: Codable {
    let id: UUID
    let timestamp: Date
    let type: String // "chipBuyIn", "chipAddOn", "сhipCashOut"
    let chipAmount: Int
}

// MARK: - Bank DTOs

/// DTO для передачи данных банка сессии
struct SessionBankTransferDTO: Codable {
    let id: UUID
    let createdAt: Date
    let isClosed: Bool
    let closedAt: Date?
    let expectedTotal: Int
    let managerPlayerID: UUID?
    let transactions: [SessionBankTransactionTransferDTO]
}

/// DTO для передачи транзакций банка
struct SessionBankTransactionTransferDTO: Codable {
    let id: UUID
    let createdAt: Date
    let amount: Int
    let type: String // "deposit", "withdrawal", "expensePayment", "tipPayment"
    let note: String
    let playerID: UUID?
    let linkedExpenseID: UUID?
}

// MARK: - Expense DTOs

/// DTO для передачи данных расхода
struct ExpenseTransferDTO: Codable {
    let id: UUID
    let amount: Int
    let note: String
    let createdAt: Date
    let paidFromRake: Int
    let paidFromBank: Int
    let payerPlayerID: UUID?
    let distributions: [ExpenseDistributionTransferDTO]
}

/// DTO для передачи распределения расхода
struct ExpenseDistributionTransferDTO: Codable {
    let id: UUID
    let playerID: UUID
    let amount: Int
}

// MARK: - Conversion Extensions (Model → DTO)

extension SessionTransferDTO {
    /// Создает DTO из модели Session
    init(from session: Session, exportDate: Date, appVersion: String) {
        self.id = session.id
        self.sessionTitle = session.sessionTitle
        self.startTime = session.startTime
        self.location = session.location
        self.gameType = session.gameType.rawValue
        self.chipsToCashRatio = session.chipsToCashRatio
        self.smallBlind = session.smallBlind
        self.bigBlind = session.bigBlind
        self.ante = session.ante
        self.status = session.status.rawValue
        self.rakeAmount = session.rakeAmount
        self.tipsAmount = session.tipsAmount
        self.tipsPaidFromBank = session.tipsPaidFromBank

        self.players = session.players.map { PlayerTransferDTO(from: $0) }
        self.bank = session.bank.map { SessionBankTransferDTO(from: $0) }
        self.expenses = session.expenses.map { ExpenseTransferDTO(from: $0) }

        self.metadata = TransferMetadata(
            formatVersion: "1.0",
            exportDate: exportDate,
            appVersion: appVersion
        )
    }
}

extension PlayerTransferDTO {
    /// Создает DTO из модели Player
    init(from player: Player) {
        self.id = player.id
        self.name = player.name
        self.inGame = player.inGame
        self.getsRakeback = player.getsRakeback
        self.rakeback = player.rakeback
        self.transactions = player.transactions.map { PlayerChipTransactionTransferDTO(from: $0) }
    }
}

extension PlayerChipTransactionTransferDTO {
    /// Создает DTO из модели PlayerChipTransaction
    init(from transaction: PlayerChipTransaction) {
        self.id = transaction.id
        self.timestamp = transaction.timestamp
        self.type = transaction.type.rawValue
        self.chipAmount = transaction.chipAmount
    }
}

extension SessionBankTransferDTO {
    /// Создает DTO из модели SessionBank
    init(from bank: SessionBank) {
        self.id = bank.id
        self.createdAt = bank.createdAt
        self.isClosed = bank.isClosed
        self.closedAt = bank.closedAt
        self.expectedTotal = bank.expectedTotal
        self.managerPlayerID = bank.manager?.id
        self.transactions = bank.transactions.map { SessionBankTransactionTransferDTO(from: $0) }
    }
}

extension SessionBankTransactionTransferDTO {
    /// Создает DTO из модели SessionBankTransaction
    init(from transaction: SessionBankTransaction) {
        self.id = transaction.id
        self.createdAt = transaction.createdAt
        self.amount = transaction.amount
        self.type = transaction.type.rawValue
        self.note = transaction.note
        self.playerID = transaction.player?.id
        self.linkedExpenseID = transaction.linkedExpense?.id
    }
}

extension ExpenseTransferDTO {
    /// Создает DTO из модели Expense
    init(from expense: Expense) {
        self.id = expense.id
        self.amount = expense.amount
        self.note = expense.note
        self.createdAt = expense.createdAt
        self.paidFromRake = expense.paidFromRake
        self.paidFromBank = expense.paidFromBank
        self.payerPlayerID = expense.payer?.id
        self.distributions = expense.distributions.map { ExpenseDistributionTransferDTO(from: $0) }
    }
}

extension ExpenseDistributionTransferDTO {
    /// Создает DTO из модели ExpenseDistribution
    init(from distribution: ExpenseDistribution) {
        self.id = distribution.id
        self.playerID = distribution.player.id
        self.amount = distribution.amount
    }
}
