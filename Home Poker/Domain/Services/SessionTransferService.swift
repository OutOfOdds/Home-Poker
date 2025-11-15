//
//  SessionTransferService.swift
//  Home Poker
//
//  Service for exporting and importing sessions to/from .pokersession files
//

import Foundation
import SwiftData

// MARK: - Protocol

/// Протокол сервиса экспорта/импорта сессий
protocol SessionTransferServiceProtocol {
    /// Экспортирует сессию в JSON данные
    /// - Parameter session: Сессия для экспорта
    /// - Returns: JSON данные готовые для записи в файл
    /// - Throws: TransferError если экспорт не удался
    func exportSession(_ session: Session) throws -> Data

    /// Импортирует сессию из JSON данных
    /// - Parameters:
    ///   - data: JSON данные из .pokersession файла
    ///   - context: ModelContext для вставки сессии
    /// - Returns: Новая созданная сессия
    /// - Throws: TransferError если импорт не удался
    func importSession(from data: Data, into context: ModelContext) throws -> Session
}

// MARK: - Error Types

/// Ошибки при экспорте/импорте сессий
enum TransferError: LocalizedError {
    case unsupportedFormatVersion(String)
    case invalidReference(String)
    case corruptedData
    case fileAccessDenied
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            return "Неподдерживаемая версия формата: \(version). Обновите приложение."
        case .invalidReference(let message):
            return "Ошибка целостности данных: \(message)"
        case .corruptedData:
            return "Поврежденный файл сессии. Попросите отправить файл заново."
        case .fileAccessDenied:
            return "Нет доступа к файлу. Проверьте разрешения."
        case .encodingFailed(let error):
            return "Ошибка кодирования: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        }
    }
}

// MARK: - Implementation

/// Реализация сервиса экспорта/импорта сессий
final class SessionTransferService: SessionTransferServiceProtocol {

    // MARK: - Export

    func exportSession(_ session: Session) throws -> Data {
        // 1. Получаем версию приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // 2. Конвертируем в DTO
        let dto = SessionTransferDTO(from: session, exportDate: Date(), appVersion: appVersion)

        // 3. Кодируем в JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(dto)
        } catch {
            throw TransferError.encodingFailed(error)
        }
    }

    // MARK: - Import

    func importSession(from data: Data, into context: ModelContext) throws -> Session {
        // 1. Декодируем JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dto: SessionTransferDTO
        do {
            dto = try decoder.decode(SessionTransferDTO.self, from: data)
        } catch {
            throw TransferError.decodingFailed(error)
        }

        // 2. Валидация
        try validateTransferData(dto)

        // 3. Создаем ID mapping (старый UUID → новый UUID)
        var idMapping: [UUID: UUID] = [:]

        // 4. Создаем Session с новым ID
        let session = Session(
            startTime: dto.startTime,
            location: dto.location,
            gameType: GameType(rawValue: dto.gameType) ?? .NLHoldem,
            status: SessionStatus(rawValue: dto.status) ?? .active,
            sessionTitle: dto.sessionTitle
        )
        session.chipsToCashRatio = dto.chipsToCashRatio
        session.smallBlind = dto.smallBlind
        session.bigBlind = dto.bigBlind
        session.ante = dto.ante
        session.rakeAmount = dto.rakeAmount
        session.tipsAmount = dto.tipsAmount
        session.tipsPaidFromBank = dto.tipsPaidFromBank

        idMapping[dto.id] = session.id

        // 5. Создаем Players с новыми ID
        for playerDTO in dto.players {
            let player = Player(
                name: playerDTO.name,
                inGame: playerDTO.inGame
            )
            player.getsRakeback = playerDTO.getsRakeback
            player.rakeback = playerDTO.rakeback

            idMapping[playerDTO.id] = player.id

            // Создаем транзакции фишек
            for txDTO in playerDTO.transactions {
                let tx = PlayerChipTransaction(
                    type: PlayerChipTransactionType(rawValue: txDTO.type) ?? .chipBuyIn,
                    amount: txDTO.chipAmount,
                    player: player,
                    timestamp: txDTO.timestamp
                )
                player.transactions.append(tx)
            }

            session.players.append(player)
        }

        // 6. Создаем Bank (если существует)
        if let bankDTO = dto.bank {
            let bank = SessionBank(
                session: session,
                createdAt: bankDTO.createdAt,
                isClosed: bankDTO.isClosed,
                closedAt: bankDTO.closedAt,
                expectedTotal: bankDTO.expectedTotal
            )

            // Устанавливаем manager используя ID mapping
            if let managerOldID = bankDTO.managerPlayerID,
               let managerNewID = idMapping[managerOldID] {
                bank.manager = session.players.first { $0.id == managerNewID }
            }

            // Создаем банковские транзакции
            for txDTO in bankDTO.transactions {
                var player: Player?
                if let playerOldID = txDTO.playerID,
                   let playerNewID = idMapping[playerOldID] {
                    player = session.players.first { $0.id == playerNewID }
                }

                let tx = SessionBankTransaction(
                    amount: txDTO.amount,
                    type: SessionBankTransactionType(rawValue: txDTO.type) ?? .deposit,
                    player: player,
                    bank: bank,
                    note: txDTO.note,
                    createdAt: txDTO.createdAt
                )

                bank.transactions.append(tx)
            }

            session.bank = bank
        }

        // 7. Создаем Expenses
        for expenseDTO in dto.expenses {
            // Находим payer используя ID mapping
            var payer: Player?
            if let payerOldID = expenseDTO.payerPlayerID,
               let payerNewID = idMapping[payerOldID] {
                payer = session.players.first { $0.id == payerNewID }
            }

            let expense = Expense(
                amount: expenseDTO.amount,
                note: expenseDTO.note,
                createdAt: expenseDTO.createdAt,
                payer: payer
            )
            expense.paidFromRake = expenseDTO.paidFromRake
            expense.paidFromBank = expenseDTO.paidFromBank

            idMapping[expenseDTO.id] = expense.id

            // Создаем распределения расходов
            for distDTO in expenseDTO.distributions {
                if let playerOldID = distDTO.playerID,
                   let playerNewID = idMapping[playerOldID],
                   let player = session.players.first(where: { $0.id == playerNewID }) {

                    let dist = ExpenseDistribution(
                        amount: distDTO.amount,
                        player: player,
                        expense: expense
                    )
                    expense.distributions.append(dist)
                }
            }

            session.expenses.append(expense)
        }

        // 8. Второй проход: Связываем bank transactions с expenses
        // (Циклическая зависимость, требует второго прохода)
        if let bank = session.bank, let bankDTO = dto.bank {
            for (index, txDTO) in bankDTO.transactions.enumerated() {
                if let linkedExpenseOldID = txDTO.linkedExpenseID {
                    // Находим новый ID расхода
                    if let linkedExpenseNewID = idMapping[linkedExpenseOldID],
                       let linkedExpense = session.expenses.first(where: { $0.id == linkedExpenseNewID }) {

                        // Находим транзакцию по индексу (порядок сохранен)
                        if index < bank.transactions.count {
                            bank.transactions[index].linkedExpense = linkedExpense
                        }
                    }
                }
            }
        }

        // 9. Вставляем сессию в контекст и сохраняем
        context.insert(session)
        try context.save()

        return session
    }

    // MARK: - Validation

    /// Валидирует целостность данных перед импортом
    private func validateTransferData(_ dto: SessionTransferDTO) throws {
        // Проверка версии формата
        guard dto.metadata.formatVersion == "1.0" else {
            throw TransferError.unsupportedFormatVersion(dto.metadata.formatVersion)
        }

        // Собираем все ID игроков
        let playerIDs = Set(dto.players.map { $0.id })

        // Валидация bank manager
        if let managerID = dto.bank?.managerPlayerID {
            guard playerIDs.contains(managerID) else {
                throw TransferError.invalidReference("Менеджер банка не найден среди игроков")
            }
        }

        // Валидация игроков в банковских транзакциях
        for tx in dto.bank?.transactions ?? [] {
            if let playerID = tx.playerID {
                guard playerIDs.contains(playerID) else {
                    throw TransferError.invalidReference("Игрок транзакции банка не найден")
                }
            }
        }

        // Валидация плательщиков расходов
        for expense in dto.expenses {
            if let payerID = expense.payerPlayerID {
                guard playerIDs.contains(payerID) else {
                    throw TransferError.invalidReference("Плательщик расхода не найден")
                }
            }

            // Валидация игроков в распределениях
            for dist in expense.distributions {
                guard playerIDs.contains(dist.playerID) else {
                    throw TransferError.invalidReference("Игрок распределения расхода не найден")
                }
            }
        }

        // Валидация связей expenses в bank transactions
        if let bankDTO = dto.bank {
            let expenseIDs = Set(dto.expenses.map { $0.id })
            for tx in bankDTO.transactions {
                if let linkedExpenseID = tx.linkedExpenseID {
                    guard expenseIDs.contains(linkedExpenseID) else {
                        throw TransferError.invalidReference("Связанный расход транзакции не найден")
                    }
                }
            }
        }
    }
}
