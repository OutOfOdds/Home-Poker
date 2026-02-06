import Foundation

struct BuiltInTemplates {

    // MARK: - Все шаблоны

    static let all: [TournamentTemplate] = [
        // Тестовый шаблон (для разработки)
        testNotifications,

        // Турбо (2 часа)
        turboSmall,
        turboMedium,
        turboLarge,

        // Стандарт (4 часа)
        standardSmall,
        standardMedium,
        standardLarge,

        // Глубокий стек (6 часов)
        deepMedium,
        deepLarge,
        deepGiant
    ]

    // MARK: - Тестовый шаблон (для проверки уведомлений)

    static let testNotifications = TournamentTemplate(
        name: "🧪 ТЕСТ (2 уровня по 1 мин)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 1),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 25, minutes: 1),
        ],
        defaultPlayers: 6,
        defaultStartingStack: 1000,
        isBuiltIn: true
    )

    // MARK: - Турбо (2 часа) - 12 уровней по 10 минут

    static let turboSmall = TournamentTemplate(
        name: "Турбо (2ч, малый стек 5K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 10),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 10),
            BlindLevel(index: 3, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 10),
            BlindLevel(index: 4, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 10),
            BlindLevel(index: 5, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 10),
            BlindLevel(index: 6, smallBlind: 200, bigBlind: 400, ante: 50, minutes: 10),
            BlindLevel(index: 7, smallBlind: 300, bigBlind: 600, ante: 75, minutes: 10),
            BlindLevel(index: 8, smallBlind: 400, bigBlind: 800, ante: 100, minutes: 10),
            BlindLevel(index: 9, smallBlind: 600, bigBlind: 1200, ante: 150, minutes: 10),
            BlindLevel(index: 10, smallBlind: 800, bigBlind: 1600, ante: 200, minutes: 10),
            BlindLevel(index: 11, smallBlind: 1000, bigBlind: 2000, ante: 250, minutes: 10),
            BlindLevel(index: 12, smallBlind: 1500, bigBlind: 3000, ante: 400, minutes: 10),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 5000,
        isBuiltIn: true
    )

    static let turboMedium = TournamentTemplate(
        name: "Турбо (2ч, средний стек 10K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 10),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 10),
            BlindLevel(index: 3, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 10),
            BlindLevel(index: 4, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 10),
            BlindLevel(index: 5, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 10),
            BlindLevel(index: 6, smallBlind: 200, bigBlind: 400, ante: 50, minutes: 10),
            BlindLevel(index: 7, smallBlind: 300, bigBlind: 600, ante: 75, minutes: 10),
            BlindLevel(index: 8, smallBlind: 500, bigBlind: 1000, ante: 125, minutes: 10),
            BlindLevel(index: 9, smallBlind: 800, bigBlind: 1600, ante: 200, minutes: 10),
            BlindLevel(index: 10, smallBlind: 1200, bigBlind: 2400, ante: 300, minutes: 10),
            BlindLevel(index: 11, smallBlind: 2000, bigBlind: 4000, ante: 500, minutes: 10),
            BlindLevel(index: 12, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 10),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 10000,
        isBuiltIn: true
    )

    static let turboLarge = TournamentTemplate(
        name: "Турбо (2ч, большой стек 20K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 10),
            BlindLevel(index: 2, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 10),
            BlindLevel(index: 3, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 10),
            BlindLevel(index: 4, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 10),
            BlindLevel(index: 5, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 10),
            BlindLevel(index: 6, smallBlind: 400, bigBlind: 800, ante: 100, minutes: 10),
            BlindLevel(index: 7, smallBlind: 600, bigBlind: 1200, ante: 150, minutes: 10),
            BlindLevel(index: 8, smallBlind: 1000, bigBlind: 2000, ante: 250, minutes: 10),
            BlindLevel(index: 9, smallBlind: 1500, bigBlind: 3000, ante: 400, minutes: 10),
            BlindLevel(index: 10, smallBlind: 2500, bigBlind: 5000, ante: 625, minutes: 10),
            BlindLevel(index: 11, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 10),
            BlindLevel(index: 12, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 10),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 20000,
        isBuiltIn: true
    )

    // MARK: - Стандарт (4 часа) - 20 уровней по 12 минут

    static let standardSmall = TournamentTemplate(
        name: "Стандарт (4ч, малый стек 5K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 250, bigBlind: 500, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 500, bigBlind: 1000, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 600, bigBlind: 1200, ante: 150, minutes: 12),
            BlindLevel(index: 12, smallBlind: 800, bigBlind: 1600, ante: 200, minutes: 12),
            BlindLevel(index: 13, smallBlind: 1000, bigBlind: 2000, ante: 250, minutes: 12),
            BlindLevel(index: 14, smallBlind: 1200, bigBlind: 2400, ante: 300, minutes: 12),
            BlindLevel(index: 15, smallBlind: 1500, bigBlind: 3000, ante: 375, minutes: 12),
            BlindLevel(index: 16, smallBlind: 2000, bigBlind: 4000, ante: 500, minutes: 12),
            BlindLevel(index: 17, smallBlind: 2500, bigBlind: 5000, ante: 625, minutes: 12),
            BlindLevel(index: 18, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 12),
            BlindLevel(index: 19, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 12),
            BlindLevel(index: 20, smallBlind: 5000, bigBlind: 10000, ante: 1250, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 5000,
        isBuiltIn: true
    )
    
    static let standardMedium = TournamentTemplate(
        name: "Стандарт (4ч, средний стек 10K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 500, bigBlind: 1000, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 600, bigBlind: 1200, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 800, bigBlind: 1600, ante: 200, minutes: 12),
            BlindLevel(index: 12, smallBlind: 1000, bigBlind: 2000, ante: 250, minutes: 12),
            BlindLevel(index: 13, smallBlind: 1500, bigBlind: 3000, ante: 375, minutes: 12),
            BlindLevel(index: 14, smallBlind: 2000, bigBlind: 4000, ante: 500, minutes: 12),
            BlindLevel(index: 15, smallBlind: 2500, bigBlind: 5000, ante: 625, minutes: 12),
            BlindLevel(index: 16, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 12),
            BlindLevel(index: 17, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 12),
            BlindLevel(index: 18, smallBlind: 5000, bigBlind: 10000, ante: 1250, minutes: 12),
            BlindLevel(index: 19, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 12),
            BlindLevel(index: 20, smallBlind: 8000, bigBlind: 16000, ante: 2000, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 10000,
        isBuiltIn: true
    )

    static let standardLarge = TournamentTemplate(
        name: "Стандарт (4ч, большой стек 20K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 600, bigBlind: 1200, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 800, bigBlind: 1600, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 1000, bigBlind: 2000, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 1200, bigBlind: 2400, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 1500, bigBlind: 3000, ante: 375, minutes: 12),
            BlindLevel(index: 12, smallBlind: 2000, bigBlind: 4000, ante: 500, minutes: 12),
            BlindLevel(index: 13, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 12),
            BlindLevel(index: 14, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 12),
            BlindLevel(index: 15, smallBlind: 5000, bigBlind: 10000, ante: 1250, minutes: 12),
            BlindLevel(index: 16, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 12),
            BlindLevel(index: 17, smallBlind: 8000, bigBlind: 16000, ante: 2000, minutes: 12),
            BlindLevel(index: 18, smallBlind: 10000, bigBlind: 20000, ante: 2500, minutes: 12),
            BlindLevel(index: 19, smallBlind: 12000, bigBlind: 24000, ante: 3000, minutes: 12),
            BlindLevel(index: 20, smallBlind: 15000, bigBlind: 30000, ante: 3750, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 20000,
        isBuiltIn: true
    )

    // MARK: - Глубокий стек (6 часов) - 30 уровней по 12 минут

    static let deepMedium = TournamentTemplate(
        name: "Глубокий стек (6ч, средний стек 10K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 25, bigBlind: 50, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 125, bigBlind: 250, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 250, bigBlind: 500, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 500, bigBlind: 1000, ante: 0, minutes: 12),
            BlindLevel(index: 12, smallBlind: 600, bigBlind: 1200, ante: 0, minutes: 12),
            BlindLevel(index: 13, smallBlind: 800, bigBlind: 1600, ante: 0, minutes: 12),
            BlindLevel(index: 14, smallBlind: 1000, bigBlind: 2000, ante: 0, minutes: 12),
            BlindLevel(index: 15, smallBlind: 1200, bigBlind: 2400, ante: 0, minutes: 12),
            BlindLevel(index: 16, smallBlind: 1500, bigBlind: 3000, ante: 375, minutes: 12),
            BlindLevel(index: 17, smallBlind: 2000, bigBlind: 4000, ante: 500, minutes: 12),
            BlindLevel(index: 18, smallBlind: 2500, bigBlind: 5000, ante: 625, minutes: 12),
            BlindLevel(index: 19, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 12),
            BlindLevel(index: 20, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 12),
            BlindLevel(index: 21, smallBlind: 5000, bigBlind: 10000, ante: 1250, minutes: 12),
            BlindLevel(index: 22, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 12),
            BlindLevel(index: 23, smallBlind: 8000, bigBlind: 16000, ante: 2000, minutes: 12),
            BlindLevel(index: 24, smallBlind: 10000, bigBlind: 20000, ante: 2500, minutes: 12),
            BlindLevel(index: 25, smallBlind: 12000, bigBlind: 24000, ante: 3000, minutes: 12),
            BlindLevel(index: 26, smallBlind: 15000, bigBlind: 30000, ante: 3750, minutes: 12),
            BlindLevel(index: 27, smallBlind: 20000, bigBlind: 40000, ante: 5000, minutes: 12),
            BlindLevel(index: 28, smallBlind: 25000, bigBlind: 50000, ante: 6250, minutes: 12),
            BlindLevel(index: 29, smallBlind: 30000, bigBlind: 60000, ante: 7500, minutes: 12),
            BlindLevel(index: 30, smallBlind: 40000, bigBlind: 80000, ante: 10000, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 10000,
        isBuiltIn: true
    )

    static let deepLarge = TournamentTemplate(
        name: "Глубокий стек (6ч, большой стек 20K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 50, bigBlind: 100, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 75, bigBlind: 150, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 250, bigBlind: 500, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 500, bigBlind: 1000, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 600, bigBlind: 1200, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 800, bigBlind: 1600, ante: 0, minutes: 12),
            BlindLevel(index: 12, smallBlind: 1000, bigBlind: 2000, ante: 0, minutes: 12),
            BlindLevel(index: 13, smallBlind: 1200, bigBlind: 2400, ante: 0, minutes: 12),
            BlindLevel(index: 14, smallBlind: 1500, bigBlind: 3000, ante: 0, minutes: 12),
            BlindLevel(index: 15, smallBlind: 2000, bigBlind: 4000, ante: 0, minutes: 12),
            BlindLevel(index: 16, smallBlind: 2500, bigBlind: 5000, ante: 625, minutes: 12),
            BlindLevel(index: 17, smallBlind: 3000, bigBlind: 6000, ante: 750, minutes: 12),
            BlindLevel(index: 18, smallBlind: 4000, bigBlind: 8000, ante: 1000, minutes: 12),
            BlindLevel(index: 19, smallBlind: 5000, bigBlind: 10000, ante: 1250, minutes: 12),
            BlindLevel(index: 20, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 12),
            BlindLevel(index: 21, smallBlind: 8000, bigBlind: 16000, ante: 2000, minutes: 12),
            BlindLevel(index: 22, smallBlind: 10000, bigBlind: 20000, ante: 2500, minutes: 12),
            BlindLevel(index: 23, smallBlind: 12000, bigBlind: 24000, ante: 3000, minutes: 12),
            BlindLevel(index: 24, smallBlind: 15000, bigBlind: 30000, ante: 3750, minutes: 12),
            BlindLevel(index: 25, smallBlind: 20000, bigBlind: 40000, ante: 5000, minutes: 12),
            BlindLevel(index: 26, smallBlind: 25000, bigBlind: 50000, ante: 6250, minutes: 12),
            BlindLevel(index: 27, smallBlind: 30000, bigBlind: 60000, ante: 7500, minutes: 12),
            BlindLevel(index: 28, smallBlind: 40000, bigBlind: 80000, ante: 10000, minutes: 12),
            BlindLevel(index: 29, smallBlind: 50000, bigBlind: 100000, ante: 12500, minutes: 12),
            BlindLevel(index: 30, smallBlind: 60000, bigBlind: 120000, ante: 15000, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 20000,
        isBuiltIn: true
    )

    static let deepGiant = TournamentTemplate(
        name: "Глубокий стек (6ч, гигантский стек 50K)",
        levels: [
            BlindLevel(index: 1, smallBlind: 100, bigBlind: 200, ante: 0, minutes: 12),
            BlindLevel(index: 2, smallBlind: 150, bigBlind: 300, ante: 0, minutes: 12),
            BlindLevel(index: 3, smallBlind: 200, bigBlind: 400, ante: 0, minutes: 12),
            BlindLevel(index: 4, smallBlind: 300, bigBlind: 600, ante: 0, minutes: 12),
            BlindLevel(index: 5, smallBlind: 400, bigBlind: 800, ante: 0, minutes: 12),
            BlindLevel(index: 6, smallBlind: 500, bigBlind: 1000, ante: 0, minutes: 12),
            BlindLevel(index: 7, smallBlind: 600, bigBlind: 1200, ante: 0, minutes: 12),
            BlindLevel(index: 8, smallBlind: 800, bigBlind: 1600, ante: 0, minutes: 12),
            BlindLevel(index: 9, smallBlind: 1000, bigBlind: 2000, ante: 0, minutes: 12),
            BlindLevel(index: 10, smallBlind: 1500, bigBlind: 3000, ante: 0, minutes: 12),
            BlindLevel(index: 11, smallBlind: 2000, bigBlind: 4000, ante: 0, minutes: 12),
            BlindLevel(index: 12, smallBlind: 2500, bigBlind: 5000, ante: 0, minutes: 12),
            BlindLevel(index: 13, smallBlind: 3000, bigBlind: 6000, ante: 0, minutes: 12),
            BlindLevel(index: 14, smallBlind: 4000, bigBlind: 8000, ante: 0, minutes: 12),
            BlindLevel(index: 15, smallBlind: 5000, bigBlind: 10000, ante: 0, minutes: 12),
            BlindLevel(index: 16, smallBlind: 6000, bigBlind: 12000, ante: 1500, minutes: 12),
            BlindLevel(index: 17, smallBlind: 8000, bigBlind: 16000, ante: 2000, minutes: 12),
            BlindLevel(index: 18, smallBlind: 10000, bigBlind: 20000, ante: 2500, minutes: 12),
            BlindLevel(index: 19, smallBlind: 12000, bigBlind: 24000, ante: 3000, minutes: 12),
            BlindLevel(index: 20, smallBlind: 15000, bigBlind: 30000, ante: 3750, minutes: 12),
            BlindLevel(index: 21, smallBlind: 20000, bigBlind: 40000, ante: 5000, minutes: 12),
            BlindLevel(index: 22, smallBlind: 25000, bigBlind: 50000, ante: 6250, minutes: 12),
            BlindLevel(index: 23, smallBlind: 30000, bigBlind: 60000, ante: 7500, minutes: 12),
            BlindLevel(index: 24, smallBlind: 40000, bigBlind: 80000, ante: 10000, minutes: 12),
            BlindLevel(index: 25, smallBlind: 50000, bigBlind: 100000, ante: 12500, minutes: 12),
            BlindLevel(index: 26, smallBlind: 60000, bigBlind: 120000, ante: 15000, minutes: 12),
            BlindLevel(index: 27, smallBlind: 80000, bigBlind: 160000, ante: 20000, minutes: 12),
            BlindLevel(index: 28, smallBlind: 100000, bigBlind: 200000, ante: 25000, minutes: 12),
            BlindLevel(index: 29, smallBlind: 125000, bigBlind: 250000, ante: 31250, minutes: 12),
            BlindLevel(index: 30, smallBlind: 150000, bigBlind: 300000, ante: 37500, minutes: 12),
        ],
        defaultPlayers: 10,
        defaultStartingStack: 50000,
        isBuiltIn: true
    )
}
