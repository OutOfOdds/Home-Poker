import Foundation

struct TimerState: Equatable {
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

protocol SessionTimerProtocol {
    func calculateCurrentLevel(effectiveElapsed: TimeInterval, items: [LevelItem]) -> (index: Int, elapsedInLevel: TimeInterval)
    func calculateLevelStartTime(for index: Int, items: [LevelItem]) -> TimeInterval
    func durationInSeconds(for item: LevelItem) -> TimeInterval
}

struct SessionTimerService: SessionTimerProtocol {
    
    /// Находит индекс уровня и время внутри него по общему прошедшему времени
    func calculateCurrentLevel(effectiveElapsed: TimeInterval, items: [LevelItem]) -> (index: Int, elapsedInLevel: TimeInterval) {
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
    func calculateLevelStartTime(for index: Int, items: [LevelItem]) -> TimeInterval {
        guard items.indices.contains(index) else { return 0 }
        
        var accumulated: TimeInterval = 0
        for i in 0..<index {
            accumulated += durationInSeconds(for: items[i])
        }
        return accumulated
    }
    
    /// Возвращает длительность уровня в секундах
    
    func durationInSeconds(for item: LevelItem) -> TimeInterval {
        switch item {
        case .blinds(let level):
            return TimeInterval(level.minutes * 60)
        case .break(let breakInfo):
            return TimeInterval(breakInfo.minutes * 60)
        }
    }
}
