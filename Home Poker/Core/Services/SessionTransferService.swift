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

    /// Возвращает имена игроков из файла, которых нет среди участников выбранного клуба.
    /// - Parameters:
    ///   - data: JSON данные из .pokersession файла
    ///   - club: Клуб, в который планируется импорт
    /// - Returns: Отсортированный список имен отсутствующих участников
    /// - Throws: TransferError если файл некорректен
    func missingClubMemberNames(from data: Data, in club: Club) throws -> [String]

    /// Импортирует сессию из JSON данных
    /// - Parameters:
    ///   - data: JSON данные из .pokersession файла
    ///   - context: ModelContext для вставки сессии
    ///   - club: Клуб, в который импортируется сессия
    /// - Returns: Новая созданная сессия
    /// - Throws: TransferError если импорт не удался
    func importSession(from data: Data, into context: ModelContext, in club: Club) throws -> Session

    /// Импортирует сессию и перед импортом добавляет в клуб выбранных недостающих участников.
    /// - Parameters:
    ///   - data: JSON данные из .pokersession файла
    ///   - context: ModelContext для вставки сессии
    ///   - club: Клуб, в который импортируется сессия
    ///   - names: Имена участников, которых нужно добавить в клуб перед импортом
    /// - Returns: Новая созданная сессия
    /// - Throws: TransferError если импорт не удался
    func importSession(from data: Data, into context: ModelContext, in club: Club, addingClubMembers names: [String]) throws -> Session
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

    func missingClubMemberNames(from data: Data, in club: Club) throws -> [String] {
        let dto = try decodeTransferData(from: data)
        try validateTransferData(dto)
        return collectMissingClubMemberNames(from: dto, in: club)
    }

    // MARK: - Import

    func importSession(from data: Data, into context: ModelContext, in club: Club) throws -> Session {
        try importSession(from: data, into: context, in: club, addingClubMembers: [])
    }

    func importSession(
        from data: Data,
        into context: ModelContext,
        in club: Club,
        addingClubMembers names: [String]
    ) throws -> Session {
        // 1. Декодируем JSON
        let dto = try decodeTransferData(from: data)

        // 2. Валидация
        try validateTransferData(dto)

        // 3. Добавляем выбранных недостающих участников в клуб до импорта
        ensureClubMembers(named: names, in: club)

        let existingClubMemberIDs = Set(club.members.map(\.id))
        let memberIDsByName = buildMemberIDMap(for: club)

        // 4. Создаем ID mapping (старый UUID → новый UUID)
        var idMapping: [UUID: UUID] = [:]

        // 5. Создаем Session с новым ID
        let session = Session(
            startTime: dto.startTime,
            gameType: GameType(rawValue: dto.gameType) ?? .NLHoldem,
            sessionType: .cash,
            status: SessionStatus(rawValue: dto.status) ?? .active,
            club: club
        )
        session.chipsToCashRatio = dto.chipsToCashRatio
        session.smallBlind = dto.smallBlind
        session.bigBlind = dto.bigBlind
        session.ante = dto.ante
        session.rakeAmount = dto.rakeAmount
        session.tipsAmount = dto.tipsAmount
        session.tipsPaidFromBank = dto.tipsPaidFromBank

        idMapping[dto.id] = session.id

        // 6. Создаем Players с новыми ID
        for playerDTO in dto.players {
            let playerName = playerDTO.name.trimmed
            let player = Player(
                name: playerName,
                inGame: playerDTO.inGame
            )
            player.clubMemberID = resolveMemberID(
                for: playerDTO,
                fallbackPlayerName: playerName,
                existingMemberIDs: existingClubMemberIDs,
                memberIDsByName: memberIDsByName
            )
            player.getsRakeback = playerDTO.getsRakeback
            player.rakeback = playerDTO.rakeback

            idMapping[playerDTO.id] = player.id

            // Создаем транзакции фишек
            for txDTO in playerDTO.transactions {
                let tx = PlayerChipTransaction(
                    type: TransactionType(rawValue: txDTO.type) ?? .chipBuyIn,
                    amount: txDTO.chipAmount,
                    player: player,
                    timestamp: txDTO.timestamp
                )
                player.transactions.append(tx)
            }

            session.players.append(player)
        }

        // 7. Создаем Bank (если существует)
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

        // 8. Создаем Expenses
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
                payer: payer,
                source: ExpenseSource(rawValue: expenseDTO.source ?? "") ?? .later
            )
            expense.paidFromRake = expenseDTO.paidFromRake
            expense.paidFromBank = expenseDTO.paidFromBank

            idMapping[expenseDTO.id] = expense.id

            // Создаем распределения расходов
            for distDTO in expenseDTO.distributions {
                let playerOldID = distDTO.playerID
                guard let playerNewID = idMapping[playerOldID],
                      let player = session.players.first(where: { $0.id == playerNewID }) else {
                    continue
                }

                let dist = ExpenseDistribution(
                    amount: distDTO.amount,
                    player: player,
                    expense: expense
                )
                expense.distributions.append(dist)
            }

            session.expenses.append(expense)
        }

        // 9. Второй проход: Связываем bank transactions с expenses
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

        // 10. Вставляем сессию в контекст и сохраняем
        context.insert(session)
        try context.save()
        ClubMemberStatsService().refreshStats(for: session)
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

    private func decodeTransferData(from data: Data) throws -> SessionTransferDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(SessionTransferDTO.self, from: data)
        } catch {
            throw TransferError.decodingFailed(error)
        }
    }

    private func collectMissingClubMemberNames(from dto: SessionTransferDTO, in club: Club) -> [String] {
        let existingClubMemberIDs = Set(club.members.map(\.id))
        let existingNames = Set(club.members.compactMap { normalizeName($0.name) })

        var seenNames: Set<String> = []
        var missingNames: [String] = []

        for player in dto.players {
            if let memberID = player.clubMemberID, existingClubMemberIDs.contains(memberID) {
                continue
            }

            guard let normalizedName = normalizeName(player.name) else { continue }
            guard !seenNames.contains(normalizedName) else { continue }
            seenNames.insert(normalizedName)

            if !existingNames.contains(normalizedName) {
                missingNames.append(player.name.trimmed)
            }
        }

        return missingNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func ensureClubMembers(named names: [String], in club: Club) {
        guard !names.isEmpty else { return }

        var existingNames = Set(club.members.compactMap { normalizeName($0.name) })

        for rawName in names {
            guard let normalizedName = normalizeName(rawName) else { continue }
            guard !existingNames.contains(normalizedName) else { continue }

            let member = ClubMember(name: rawName, club: club)
            club.members.append(member)
            existingNames.insert(normalizedName)
        }
    }

    private func buildMemberIDMap(for club: Club) -> [String: UUID] {
        var map: [String: UUID] = [:]
        for member in club.members {
            guard let normalizedName = normalizeName(member.name) else { continue }
            if map[normalizedName] == nil {
                map[normalizedName] = member.id
            }
        }
        return map
    }

    private func resolveMemberID(
        for player: PlayerTransferDTO,
        fallbackPlayerName: String,
        existingMemberIDs: Set<UUID>,
        memberIDsByName: [String: UUID]
    ) -> UUID? {
        if let clubMemberID = player.clubMemberID, existingMemberIDs.contains(clubMemberID) {
            return clubMemberID
        }

        guard let normalizedName = normalizeName(fallbackPlayerName) else { return nil }
        return memberIDsByName[normalizedName]
    }

    private func normalizeName(_ name: String) -> String? {
        name.nonEmptyTrimmed?.lowercased()
    }
}
