import Foundation

// MARK: - Timer State

struct TimerState: Equatable, Sendable {
    public var currentLevelIndex: Int
    public var currentItem: LevelItem
    public var elapsedTimeInLevel: TimeInterval
    public var remainingTimeInLevel: TimeInterval
    public var totalElapsedTime: TimeInterval
    public var isRunning: Bool
    public var isPaused: Bool

    public init(
        currentLevelIndex: Int,
        currentItem: LevelItem,
        elapsedTimeInLevel: TimeInterval,
        remainingTimeInLevel: TimeInterval,
        totalElapsedTime: TimeInterval,
        isRunning: Bool,
        isPaused: Bool
    ) {
        self.currentLevelIndex = currentLevelIndex
        self.currentItem = currentItem
        self.elapsedTimeInLevel = elapsedTimeInLevel
        self.remainingTimeInLevel = remainingTimeInLevel
        self.totalElapsedTime = totalElapsedTime
        self.isRunning = isRunning
        self.isPaused = isPaused
    }
}

// MARK: - Session Timer Protocol

protocol SessionTimerProtocol: Sendable {
    func calculateCurrentLevel(effectiveElapsed: TimeInterval, items: [LevelItem]) -> (index: Int, elapsedInLevel: TimeInterval)
    func calculateLevelStartTime(for index: Int, items: [LevelItem]) -> TimeInterval
    func durationInSeconds(for item: LevelItem) -> TimeInterval
}

// MARK: - Timer Service Implementation

struct TimerService: SessionTimerProtocol {

    // MARK: - Level Calculations

    /// Находит индекс уровня и время внутри него по общему прошедшему времени
    nonisolated func calculateCurrentLevel(effectiveElapsed: TimeInterval, items: [LevelItem]) -> (index: Int, elapsedInLevel: TimeInterval) {
        var accumulated: TimeInterval = 0

        for (index, item) in items.enumerated() {
            let duration = durationInSeconds(for: item)

            if effectiveElapsed < accumulated + duration {
                // Нашли нужный уровень
                let elapsedInLevel = effectiveElapsed - accumulated
                return (index, elapsedInLevel)
            }

            accumulated += duration
        }

        // Если время вышло за пределы всех уровней
        let lastIndex = max(0, items.count - 1)
        let lastDuration = durationInSeconds(for: items[lastIndex])
        return (lastIndex, lastDuration)
    }

    /// Рассчитывает время начала конкретного уровня (в секундах от старта)
    nonisolated func calculateLevelStartTime(for index: Int, items: [LevelItem]) -> TimeInterval {
        guard items.indices.contains(index) else { return 0 }

        var accumulated: TimeInterval = 0
        for i in 0..<index {
            accumulated += durationInSeconds(for: items[i])
        }
        return accumulated
    }

    // MARK: - Duration Calculations

    /// Возвращает длительность уровня в секундах
    nonisolated func durationInSeconds(for item: LevelItem) -> TimeInterval {
        switch item {
        case .blinds(let level):
            return TimeInterval(level.minutes * 60)
        case .break(let breakInfo):
            return TimeInterval(breakInfo.minutes * 60)
        }
    }
}
