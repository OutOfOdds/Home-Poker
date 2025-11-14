import Foundation
import SwiftData

protocol SessionServiceProtocol {
    // Управление игроком
    func addPlayer(name: String, buyIn: Int, to session: Session) throws
    func addOn(player: Player, amount: Int, in session: Session) throws
    func cashOut(player: Player, amount: Int, in session: Session) throws
    func returnPlayerWithRebuy(_ player: Player, amount: Int, in session: Session) throws
    func removePlayer(_ player: Player, from session: Session)
    func removeTransaction(_ transaction: PlayerChipTransaction, from session: Session)

    // Управление банком
    @discardableResult
    func ensureBank(for session: Session) -> SessionBank
    func setBankManager(_ player: Player?, for session: Session)
    func recordBankTransaction(for session: Session, player: Player?, amount: Int, note: String?, type: SessionBankTransactionType, linkedExpense: Expense?) throws
    func removeBankTransaction(_ transaction: SessionBankTransaction, from session: Session) throws

    // Управление расходами
    func addExpense(note: String, amount: Int, payer: Player?, to session: Session, createdAt: Date) throws
    func removeExpenses(_ expenses: [Expense], from session: Session)
    func saveExpenseDistribution(for expense: Expense, distributions: [(Player, Int)], rakeAmount: Int) throws

    // Рейк и чаевые
    func recordRakeAndTips(for session: Session, rake: Int, tips: Int) throws
    func clearRakeAndTips(for session: Session)

    // Распределение рейкбека
    func saveRakebackDistribution(for session: Session, distributions: [(player: Player, amount: Int)]) throws

    // Настройки сессии
    func updateBlinds(for session: Session, small: Int, big: Int, ante: Int) throws
}

struct SessionService: SessionServiceProtocol {
    // MARK: - Игрок

    // Создаёт нового игрока, фиксирует первичный buy-in и добавляет его в сессию.
    func addPlayer(name: String, buyIn: Int, to session: Session) throws {
        let trimmedName = try normalizePlayerName(name)
        try validatePositiveAmount(buyIn)
        
        let player = Player(name: trimmedName, inGame: true)
        let transaction = PlayerChipTransaction(type: .chipBuyIn, amount: buyIn, player: player)
        player.transactions.append(transaction)
        session.players.append(player)
        refreshBankExpectation(for: session)
    }
    
    // Регистрирует докупку (add-on) для игрока в рамках сессии.
    func addOn(player: Player, amount: Int, in session: Session) throws {
        try validatePositiveAmount(amount)
        let transaction = PlayerChipTransaction(type: .chipAddOn, amount: amount, player: player)
        player.transactions.append(transaction)
        refreshBankExpectation(for: session)
    }
    
    // Завершает игру для игрока: фиксирует вывод средств и помечает его как выбывшего.
    func cashOut(player: Player, amount: Int, in session: Session) throws {
        try validateNonNegativeAmount(amount)
        guard amount <= session.chipsInGame else {
            throw SessionServiceError.insufficientBank
        }

        let transaction = PlayerChipTransaction(type: .сhipCashOut, amount: amount, player: player)
        player.transactions.append(transaction)
        player.inGame = false
        refreshBankExpectation(for: session)
    }

    // Возвращает игрока в игру с новой закупкой.
    // В реальной покерной игре возврат игрока всегда означает новую закупку фишек.
    func returnPlayerWithRebuy(_ player: Player, amount: Int, in session: Session) throws {
        guard !player.inGame else {
            throw SessionServiceError.playerAlreadyInGame
        }
        try validatePositiveAmount(amount)

        // Новая закупка при возврате - это новые деньги в банк
        let transaction = PlayerChipTransaction(type: .chipBuyIn, amount: amount, player: player)
        player.transactions.append(transaction)
        player.inGame = true
        refreshBankExpectation(for: session)
    }
    
    // Удаляет игрока из сессии вместе со всеми связанными транзакциями.
    /// SwiftData автоматически:
    /// - Удаляет все PlayerTransaction (deleteRule: .cascade)
    /// - Удаляет все SessionBankTransaction (deleteRule: .cascade)
    /// - Обнуляет Expense.payer (deleteRule: .nullify)
    func removePlayer(_ player: Player, from session: Session) {
        session.players.removeAll { $0.id == player.id }
        player.modelContext?.delete(player)
        refreshBankExpectation(for: session)
    }

    // Удаляет транзакцию игрока и обновляет состояние сессии.
    func removeTransaction(_ transaction: PlayerChipTransaction, from session: Session) {
        if let player = transaction.player {
            player.transactions.removeAll { $0.id == transaction.id }
            if transaction.type == .сhipCashOut {
                let hasCashOut = player.transactions.contains { $0.type == .сhipCashOut }
                player.inGame = !hasCashOut
            }
        }
        transaction.modelContext?.delete(transaction)
        refreshBankExpectation(for: session)
    }
    
    // MARK: - Банк сессии

    // Гарантирует наличие банка у сессии (создаёт при отсутствии) и актуализирует ожидаемую сумму.
    @discardableResult
    func ensureBank(for session: Session) -> SessionBank {
        if let existing = session.bank {
            existing.expectedTotal = expectedBankTotal(for: session)
            return existing
        }

        let bank = SessionBank(session: session, expectedTotal: expectedBankTotal(for: session))
        session.bank = bank
        return bank
    }

    // Назначает (или убирает) ответственного за сессионный банк.
    func setBankManager(_ player: Player?, for session: Session) {
        let bank = ensureBank(for: session)
        bank.manager = player
    }

    // Регистрирует операцию с банком сессии (пополнение, выдачу, оплату расходов или чаевых).
    func recordBankTransaction(
        for session: Session,
        player: Player?,
        amount: Int,
        note: String?,
        type: SessionBankTransactionType,
        linkedExpense: Expense? = nil
    ) throws {
        try validatePositiveAmount(amount)
        let bank = ensureBank(for: session)

        // Проверка игрока только для deposit/withdrawal
        if let player = player {
            guard session.players.contains(where: { $0.id == player.id }) else {
                throw SessionServiceError.playerNotInSession
            }
        }

        // Проверка достаточности средств для выдач
        if type == .withdrawal || type == .expensePayment || type == .tipPayment {
            guard bank.netBalance >= amount else {
                throw SessionServiceError.insufficientBankBalance
            }
        }

        let entry = SessionBankTransaction(
            amount: amount,
            type: type,
            player: player,
            bank: bank,
            note: trimmedNote(note)
        )
        entry.linkedExpense = linkedExpense
        bank.transactions.append(entry)

        // Обновление связанных сущностей
        if let expense = linkedExpense, type == .expensePayment {
            expense.paidFromBank += amount
        } else if type == .tipPayment {
            session.tipsPaidFromBank += amount
        }
    }

    // Удаляет транзакцию банка и обновляет состояние сессии.
    func removeBankTransaction(_ transaction: SessionBankTransaction, from session: Session) throws {
        guard let bank = session.bank else {
            throw SessionServiceError.bankUnavailable
        }
        bank.transactions.removeAll { $0.id == transaction.id }
        transaction.modelContext?.delete(transaction)
    }

    // MARK: - Расходы
    
    // Регистрирует расход, совершённый в рамках сессии.
    func addExpense(note: String, amount: Int, payer: Player?, to session: Session, createdAt: Date) throws {
        try validatePositiveAmount(amount)
        let trimmedNote = note.trimmed
        let expense = Expense(amount: amount, note: trimmedNote, createdAt: createdAt, payer: payer)
        session.expenses.append(expense)
    }
    
    // Удаляет указанные расходы из сессии.
    func removeExpenses(_ expenses: [Expense], from session: Session) {
        let ids = expenses.map { $0.id }
        session.expenses.removeAll { ids.contains($0.id) }
    }

    // Сохраняет распределение расхода между игроками и суммой из рейка
    // Расход может быть оплачен частично/полностью из рейка и/или распределён между игроками
    func saveExpenseDistribution(
        for expense: Expense,
        distributions: [(Player, Int)],
        rakeAmount: Int
    ) throws {
        // Валидация: сумма распределения + rakeAmount должна равняться сумме расхода
        let totalDistributed = distributions.reduce(0) { $0 + $1.1 }
        guard totalDistributed + rakeAmount == expense.amount else {
            throw SessionServiceError.invalidAmount
        }

        // Валидация: все суммы должны быть положительными
        for (_, amount) in distributions {
            try validatePositiveAmount(amount)
        }

        // Валидация: rakeAmount должен быть неотрицательным
        try validateNonNegativeAmount(rakeAmount)

        // Удаляем старые распределения
        expense.distributions.removeAll()

        // Создаем новые распределения
        for (player, amount) in distributions {
            let distribution = ExpenseDistribution(amount: amount, player: player, expense: expense)
            expense.distributions.append(distribution)
        }

        // Устанавливаем сумму, оплаченную из рейка
        expense.paidFromRake = rakeAmount
    }


    // MARK: - Рейк и чаевые

    /// Записывает рейк и чаевые из остатка фишек на столе
    /// Сохраняет только информационные значения в Session, не создаёт транзакции
    /// Рейк и чаевые автоматически учитываются в балансе банка через разницу депозитов/снятий
    /// - Parameters:
    ///   - session: Сессия
    ///   - rake: Количество фишек рейка
    ///   - tips: Количество фишек чаевых
    /// - Throws: SessionServiceError если валидация не прошла
    func recordRakeAndTips(for session: Session, rake: Int, tips: Int) throws {
        try validateNonNegativeAmount(rake)
        try validateNonNegativeAmount(tips)

        let total = rake + tips
        guard total <= session.chipsInGame else {
            throw SessionServiceError.rakeExceedsRemaining
        }

        // Записываем информацию о рейке и чаевых в Session (в фишках)
        // Эти значения объясняют, почему в балансе банка остаются деньги
        // Транзакции НЕ создаются - баланс уже корректен через депозиты/снятия игроков
        session.rakeAmount = rake
        session.tipsAmount = tips

        // Создаём банк если его нет (для корректного отображения в UI)
        _ = ensureBank(for: session)
    }

    /// Очищает записанные рейк и чаевые
    /// Используется для отмены распределения остатков
    /// - Parameter session: Сессия
    func clearRakeAndTips(for session: Session) {
        session.rakeAmount = 0
        session.tipsAmount = 0
    }

    // MARK: - Распределение рейкбека

    /// Сохраняет распределение рейкбека между игроками
    /// Устанавливает флаг getsRakeback и сумму rakeback для каждого игрока
    /// - Parameters:
    ///   - session: Сессия
    ///   - distributions: Массив кортежей (игрок, сумма) с распределением рейкбека
    /// - Throws: SessionServiceError если валидация не прошла
    func saveRakebackDistribution(
        for session: Session,
        distributions: [(player: Player, amount: Int)]
    ) throws {
        // Валидация: все суммы должны быть неотрицательными
        for (_, amount) in distributions {
            try validateNonNegativeAmount(amount)
        }

        // Валидация: все игроки должны быть в сессии
        let sessionPlayerIds = Set(session.players.map { $0.id })
        for (player, _) in distributions {
            guard sessionPlayerIds.contains(player.id) else {
                throw SessionServiceError.playerNotInSession
            }
        }

        // Валидация: сумма распределения не должна превышать доступный рейкбек
        let totalDistributed = distributions.reduce(0) { $0 + $1.amount }
        let availableRakeback = (session.bank?.reservedForRake ?? 0)
        guard totalDistributed <= availableRakeback else {
            throw SessionServiceError.rakebackExceedsAvailable
        }

        // Обнуляем рейкбек у всех игроков
        for player in session.players {
            player.getsRakeback = false
            player.rakeback = 0
        }

        // Устанавливаем новое распределение
        for (player, amount) in distributions where amount > 0 {
            player.getsRakeback = true
            player.rakeback = amount
        }
    }

    // MARK: - Настройки сессии
    // Обновляет параметры блайндов и анте у сессии.
    func updateBlinds(for session: Session, small: Int, big: Int, ante: Int) throws {
        guard small > 0, big > 0, small <= big else {
            throw SessionServiceError.invalidBlinds
        }
        
        session.smallBlind = small
        session.bigBlind = big
        session.ante = max(0, ante)
    }

    // MARK: - Вспомогательные методы
    
    private func normalizePlayerName(_ name: String) throws -> String {
        guard let trimmed = name.nonEmptyTrimmed else { throw SessionServiceError.emptyPlayerName }
        return trimmed
    }
    
    private func validatePositiveAmount(_ amount: Int) throws {
        guard amount > 0 else { throw SessionServiceError.invalidAmount }
    }
    
    private func validateNonNegativeAmount(_ amount: Int) throws {
        guard amount >= 0 else { throw SessionServiceError.invalidAmount }
    }

    private func refreshBankExpectation(for session: Session) {
        session.bank?.expectedTotal = expectedBankTotal(for: session)
    }
    
    private func trimmedNote(_ note: String?) -> String {
        note?.trimmed ?? ""
    }

    private func expectedBankTotal(for session: Session) -> Int {
        session.players
            .filter { !$0.inGame }
            .reduce(0) { partial, player in
                let chipBalance = max(player.chipBuyIn - player.chipCashOut, 0)
                let cashBalance = chipBalance * session.chipsToCashRatio
                return partial + cashBalance    
            }
    }
}

enum SessionServiceError: LocalizedError {
    case insufficientBank
    case insufficientBankBalance
    case invalidAmount
    case emptyPlayerName
    case invalidBlinds
    case bankUnavailable
    case playerNotInSession
    case playerAlreadyInGame
    case rakeExceedsRemaining
    case rakebackExceedsAvailable

    var errorDescription: String? {
        switch self {
        case .insufficientBank:
            return "Нельзя вывести больше, чем осталось в банке игры."
        case .insufficientBankBalance:
            return "Недостаточно средств в банке для выполнения операции."
        case .invalidAmount:
            return "Сумма должна быть больше нуля."
        case .emptyPlayerName:
            return "Введите имя игрока."
        case .invalidBlinds:
            return "Укажите корректные значения блайндов."
        case .bankUnavailable:
            return "Не удалось получить банк для сессии."
        case .playerNotInSession:
            return "Игрок не найден в этой сессии."
        case .playerAlreadyInGame:
            return "Игрок уже в игре."
        case .rakeExceedsRemaining:
            return "Сумма рейка и чаевых превышает остаток фишек на столе."
        case .rakebackExceedsAvailable:
            return "Сумма распределения рейкбека превышает доступную сумму."
        }
    }
}
