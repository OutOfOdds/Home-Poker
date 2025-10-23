import Foundation
import SwiftData

/// Фабрика для создания мокап данных для SwiftUI превью
/// Использование: let session = PreviewData.activeSession()
enum PreviewData {

    // MARK: - Sessions

    /// Активная сессия с 9 игроками в разных состояниях
    static func activeSession() -> Session {
        let session = Session(
            startTime: Date().addingTimeInterval(-3 * 60 * 60), // 3 часа назад
            location: "Покер Клуб Москва",
            gameType: .NLHoldem,
            status: .active,
            sessionTitle: "Вечерняя игра"
        )
        session.smallBlind = 10
        session.bigBlind = 20
        session.ante = 0

        // Активные игроки
        let activePlayer1 = createPlayer(name: "Дмитрий", inGame: true, buyIn: 5000, addOns: [500])
        let activePlayer2 = createPlayer(name: "Александр", inGame: true, buyIn: 3000)
        let activePlayer3 = createPlayer(name: "Максим", inGame: true, buyIn: 1500, addOns: [1000, 500])

        // Завершившие игру игроки
        let finishedWinner = createPlayer(name: "Сергей", inGame: false, buyIn: 2000, cashOut: 5500)
        let finishedLoser = createPlayer(name: "Андрей", inGame: false, buyIn: 3000, addOns: [1000], cashOut: 2000)
        let finishedBreakEven = createPlayer(name: "Иван", inGame: false, buyIn: 2500, cashOut: 2500)

        // Игрок с рейкбеком
        let rakebackPlayer = createPlayer(name: "Владимир", inGame: true, buyIn: 2000, getsRakeback: true)

        // Еще активные
        let activePlayer4 = createPlayer(name: "Николай", inGame: true, buyIn: 1800)
        let activePlayer5 = createPlayer(name: "Евгений", inGame: true, buyIn: 2200, addOns: [800])

        session.players = [
            activePlayer1, activePlayer2, activePlayer3,
            finishedWinner, finishedLoser, finishedBreakEven,
            rakebackPlayer, activePlayer4, activePlayer5
        ]

        // Расходы
        session.expenses = [
            createExpense(amount: 500, note: "Напитки", payer: activePlayer1),
            createExpense(amount: 300, note: "Еда", payer: finishedWinner),
            createExpense(amount: 150, note: "Чаевые дилеру", payer: nil)
        ]

        return session
    }

    /// Завершенная сессия с балансированным результатом
    static func finishedSession() -> Session {
        let session = Session(
            startTime: Date().addingTimeInterval(-6 * 60 * 60), // 6 часов назад
            location: "Royal Flush Club",
            gameType: .PLO4,
            status: .finished,
            sessionTitle: "Дневная игра"
        )
        session.smallBlind = 5
        session.bigBlind = 10
        session.ante = 2

        let winner1 = createPlayer(name: "Алексей", inGame: false, buyIn: 2000, cashOut: 4200)
        let winner2 = createPlayer(name: "Михаил", inGame: false, buyIn: 1500, addOns: [1000], cashOut: 3800)
        let loser1 = createPlayer(name: "Олег", inGame: false, buyIn: 3000, addOns: [1000], cashOut: 1500)
        let loser2 = createPlayer(name: "Павел", inGame: false, buyIn: 2500, cashOut: 1000)
        let breakEven = createPlayer(name: "Артем", inGame: false, buyIn: 2000, cashOut: 2000)

        session.players = [winner1, winner2, loser1, loser2, breakEven]

        session.expenses = [
            createExpense(amount: 800, note: "Аренда стола", payer: winner1)
        ]

        return session
    }

    /// Сессия ожидающая расчетов
    static func awaitingSettlementsSession() -> Session {
        let session = Session(
            startTime: Date().addingTimeInterval(-4 * 60 * 60),
            location: "Покерный дом",
            gameType: .NLHoldem,
            status: .awaitingForSettlements,
            sessionTitle: "Кайфушки у Грикушки"
        )
        session.smallBlind = 25
        session.bigBlind = 50
        session.ante = 5

        let bigWinner = createPlayer(name: "Виктор", inGame: false, buyIn: 5000, addOns: [2000], cashOut: 12000)
        let smallWinner = createPlayer(name: "Юрий", inGame: false, buyIn: 3000, cashOut: 4500)
        let bigLoser = createPlayer(name: "Константин", inGame: false, buyIn: 6000, addOns: [3000], cashOut: 2000)
        let moderateLoser = createPlayer(name: "Роман", inGame: false, buyIn: 4000, cashOut: 2500)

        session.players = [bigWinner, smallWinner, bigLoser, moderateLoser]

        return session
    }

    /// Сессия с банком
    static func sessionWithBank() -> Session {
        let session = activeSession()

        let bank = SessionBank(session: session, expectedTotal: 10000)
        bank.manager = session.players.first

        // Добавляем несколько записей в банк
        let entry1 = SessionBankTransaction(
            amount: 5000,
            type: .deposit,
            player: session.players[0],
            bank: bank,
            note: "Внесение в банк",
            createdAt: Date().addingTimeInterval(-2 * 60 * 60)
        )
        let entry2 = SessionBankTransaction(
            amount: 3000,
            type: .deposit,
            player: session.players[1],
            bank: bank,
            note: "Внесение в банк",
            createdAt: Date().addingTimeInterval(-1 * 60 * 60)
        )
        let entry3 = SessionBankTransaction(
            amount: 2000,
            type: .withdrawal,
            player: session.players[3],
            bank: bank,
            note: "Выплата",
            createdAt: Date().addingTimeInterval(-30 * 60)
        )

        bank.entries = [entry1, entry2, entry3]
        session.bank = bank

        return session
    }

    /// Пустая новая сессия
    static func emptySession() -> Session {
        Session(
            startTime: Date(),
            location: "",
            gameType: .NLHoldem,
            status: .active,
            sessionTitle: "Новая игра"
        )
    }

    // MARK: - Players

    /// Активный игрок с buy-in
    static func activePlayer() -> Player {
        createPlayer(name: "Дмитрий", inGame: true, buyIn: 2000)
    }

    /// Игрок с несколькими add-on
    static func playerWithAddOns() -> Player {
        createPlayer(name: "Александр", inGame: true, buyIn: 2000, addOns: [1000, 500, 500])
    }

    /// Победитель
    static func winnerPlayer() -> Player {
        createPlayer(name: "Сергей", inGame: false, buyIn: 2000, cashOut: 5500)
    }

    /// Проигравший
    static func loserPlayer() -> Player {
        createPlayer(name: "Андрей", inGame: false, buyIn: 3000, addOns: [1000], cashOut: 2000)
    }

    /// Игрок с рейкбеком
    static func rakebackPlayer() -> Player {
        createPlayer(name: "Владимир", inGame: true, buyIn: 2000, getsRakeback: true)
    }

    // MARK: - Expenses

    /// Стандартные расходы
    static func sampleExpenses(for players: [Player]) -> [Expense] {
        [
            createExpense(amount: 500, note: "Напитки", payer: players.first),
            createExpense(amount: 300, note: "Еда", payer: players.count > 1 ? players[1] : nil),
            createExpense(amount: 150, note: "Чаевые дилеру", payer: nil)
        ]
    }

    /// Одиночный расход
    static func singleExpense(payer: Player? = nil) -> Expense {
        createExpense(amount: 500, note: "Напитки", payer: payer)
    }

    // MARK: - Session Bank

    /// Банк с транзакциями
    static func sampleBank(for session: Session) -> SessionBank {
        let bank = SessionBank(session: session, expectedTotal: 10000)
        bank.manager = session.players.first

        if session.players.count >= 3 {
            let entry1 = SessionBankTransaction(
                amount: 5000,
                type: .deposit,
                player: session.players[0],
                bank: bank,
                note: "Внесение в банк",
                createdAt: Date().addingTimeInterval(-2 * 60 * 60)
            )
            let entry2 = SessionBankTransaction(
                amount: 3000,
                type: .deposit,
                player: session.players[1],
                bank: bank,
                note: "Внесение в банк",
                createdAt: Date().addingTimeInterval(-1 * 60 * 60)
            )
            bank.entries = [entry1, entry2]
        }

        return bank
    }

    // MARK: - Helper Methods

    /// Создает игрока с транзакциями
    private static func createPlayer(
        name: String,
        inGame: Bool,
        buyIn: Int,
        addOns: [Int] = [],
        cashOut: Int? = nil,
        getsRakeback: Bool = false
    ) -> Player {
        let player = Player(name: name, inGame: inGame)
        player.getsRakeback = getsRakeback
        if getsRakeback {
            player.rakeback = 100 // Пример рейкбека
        }

        var transactions: [PlayerTransaction] = []

        // Buy-in
        transactions.append(PlayerTransaction(
            type: .buyIn,
            amount: buyIn,
            player: player,
            timestamp: Date().addingTimeInterval(-3 * 60 * 60)
        ))

        // Add-ons
        for (index, addOn) in addOns.enumerated() {
            transactions.append(PlayerTransaction(
                type: .addOn,
                amount: addOn,
                player: player,
                timestamp: Date().addingTimeInterval(-Double(2 * 60 * 60 - index * 30 * 60))
            ))
        }

        // Cash-out
        if let cashOut = cashOut {
            transactions.append(PlayerTransaction(
                type: .cashOut,
                amount: cashOut,
                player: player,
                timestamp: Date().addingTimeInterval(-30 * 60)
            ))
        }

        player.transactions = transactions
        return player
    }

    /// Создает расход
    private static func createExpense(amount: Int, note: String, payer: Player?) -> Expense {
        Expense(
            amount: amount,
            note: note,
            createdAt: Date().addingTimeInterval(-Double.random(in: 60...180) * 60),
            payer: payer
        )
    }

    // MARK: - Multiple Sessions

    /// Список сессий для превью SessionListView
    static func sampleSessions() -> [Session] {
        [
            activeSession(),
            finishedSession(),
            awaitingSettlementsSession()
        ]
    }

    // MARK: - ModelContainer для превью

    /// Стандартный ModelContainer для превью
    @MainActor
    static var previewContainer: ModelContainer {
        let schema = Schema([
            Session.self,
            Player.self,
            PlayerTransaction.self,
            Expense.self,
            SessionBank.self,
            SessionBankTransaction.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])

            // Добавляем примеры данных
            let context = container.mainContext
            let sessions = sampleSessions()
            sessions.forEach { context.insert($0) }

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
