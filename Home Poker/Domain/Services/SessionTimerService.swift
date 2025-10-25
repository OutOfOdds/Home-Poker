//
//  SessionTimerService.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import Foundation

// MARK: - Timer State

public struct TimerState: Equatable {
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

// MARK: - Protocol

public protocol SessionTimerServiceProtocol {
    /// Запускает таймер с указанной структурой уровней
    func start(items: [LevelItem], startedAt: Date)

    /// Ставит таймер на паузу
    func pause()

    /// Возобновляет таймер после паузы
    func resume()

    /// Останавливает таймер полностью
    func stop()

    /// Переходит к следующему уровню
    func skipToNext()

    /// Возвращается к предыдущему уровню
    func skipToPrevious()

    /// Переходит к конкретному уровню по индексу
    func jumpToLevel(at index: Int)

    /// Текущее состояние таймера
    var currentState: TimerState? { get }
}

// MARK: - Implementation

@Observable
public final class SessionTimerService: SessionTimerServiceProtocol {

    // MARK: - Private Properties

    private var timer: Timer?
    private var items: [LevelItem] = []

    // Абсолютное время старта (основа всех расчётов)
    private var absoluteStartDate: Date?

    // Время паузы
    private var pausedAt: Date?
    private var accumulatedPausedTime: TimeInterval = 0

    // Текущий индекс уровня
    private var currentIndex: Int = 0

    // Смещение при ручных переходах между уровнями
    private var manualTimeOffset: TimeInterval = 0

    // MARK: - Public Properties

    public private(set) var currentState: TimerState?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    public func start(items: [LevelItem], startedAt: Date = Date()) {
        guard !items.isEmpty else { return }

        // Сброс состояния
        stop()

        self.items = items
        self.absoluteStartDate = startedAt
        self.currentIndex = 0
        self.accumulatedPausedTime = 0
        self.manualTimeOffset = 0
        self.pausedAt = nil

        // Запуск таймера
        startTicking()

        // Немедленный расчёт состояния
        tick()
    }

    public func pause() {
        guard currentState?.isRunning == true, currentState?.isPaused == false else { return }

        pausedAt = Date()
        stopTicking()

        // Обновляем состояние
        if let state = currentState {
            let pausedState = TimerState(
                currentLevelIndex: state.currentLevelIndex,
                currentItem: state.currentItem,
                elapsedTimeInLevel: state.elapsedTimeInLevel,
                remainingTimeInLevel: state.remainingTimeInLevel,
                totalElapsedTime: state.totalElapsedTime,
                isRunning: true,
                isPaused: true
            )
            currentState = pausedState
        }
    }

    public func resume() {
        guard currentState?.isRunning == true, currentState?.isPaused == true else { return }
        guard let pausedAt = pausedAt else { return }

        // Добавляем время паузы к накопленному
        let pauseDuration = Date().timeIntervalSince(pausedAt)
        accumulatedPausedTime += pauseDuration
        self.pausedAt = nil

        // Возобновляем тикание
        startTicking()
        tick()
    }

    public func stop() {
        stopTicking()

        absoluteStartDate = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        manualTimeOffset = 0
        currentIndex = 0
        currentState = nil
        // НЕ очищаем items - структура блайндов должна сохраняться
    }

    public func skipToNext() {
        guard currentIndex < items.count - 1 else { return }
        jumpToLevel(at: currentIndex + 1)
    }

    public func skipToPrevious() {
        guard currentIndex > 0 else { return }
        jumpToLevel(at: currentIndex - 1)
    }

    public func jumpToLevel(at index: Int) {
        guard items.indices.contains(index) else { return }
        guard let absoluteStartDate = absoluteStartDate else { return }

        let wasPaused = currentState?.isPaused ?? false

        // Рассчитываем время начала целевого уровня
        let targetLevelStartTime = calculateLevelStartTime(for: index)

        // Текущее эффективное время
        let now = Date()
        let currentEffectiveTime = now.timeIntervalSince(absoluteStartDate) - accumulatedPausedTime

        // Новое смещение = разница между текущим временем и началом целевого уровня
        manualTimeOffset = currentEffectiveTime - targetLevelStartTime

        currentIndex = index

        // Если были на паузе, сохраняем паузу
        if wasPaused {
            pausedAt = now
        }

        tick()
    }

    // MARK: - Private Methods

    private func startTicking() {
        stopTicking()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Добавляем в RunLoop для работы в фоне
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let absoluteStartDate = absoluteStartDate else { return }

        let now = Date()

        // Эффективное прошедшее время с учётом пауз и смещений
        let effectiveElapsed: TimeInterval
        if let pausedAt = pausedAt {
            // На паузе - время не идёт
            effectiveElapsed = pausedAt.timeIntervalSince(absoluteStartDate) - accumulatedPausedTime - manualTimeOffset
        } else {
            effectiveElapsed = now.timeIntervalSince(absoluteStartDate) - accumulatedPausedTime - manualTimeOffset
        }

        // Определяем текущий уровень и время в нём
        let (levelIndex, elapsedInLevel) = findCurrentLevel(effectiveElapsed: effectiveElapsed)

        // Если автоматически перешли на новый уровень
        if levelIndex != currentIndex {
            currentIndex = levelIndex
        }

        // Если дошли до конца всех уровней
        guard items.indices.contains(currentIndex) else {
            stop()
            return
        }

        let currentItem = items[currentIndex]
        let levelDuration = durationInSeconds(for: currentItem)
        let remainingInLevel = max(0, levelDuration - elapsedInLevel)

        // Создаём состояние
        let state = TimerState(
            currentLevelIndex: currentIndex,
            currentItem: currentItem,
            elapsedTimeInLevel: elapsedInLevel,
            remainingTimeInLevel: remainingInLevel,
            totalElapsedTime: effectiveElapsed,
            isRunning: true,
            isPaused: pausedAt != nil
        )

        currentState = state
    }

    /// Находит индекс уровня и время внутри него по общему прошедшему времени
    private func findCurrentLevel(effectiveElapsed: TimeInterval) -> (index: Int, elapsedInLevel: TimeInterval) {
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
    private func calculateLevelStartTime(for index: Int) -> TimeInterval {
        guard items.indices.contains(index) else { return 0 }

        var accumulated: TimeInterval = 0
        for i in 0..<index {
            accumulated += durationInSeconds(for: items[i])
        }
        return accumulated
    }

    /// Возвращает длительность уровня в секундах
    private func durationInSeconds(for item: LevelItem) -> TimeInterval {
        switch item {
        case .blinds(let level):
            return TimeInterval(level.minutes * 60)
        case .break(let breakInfo):
            return TimeInterval(breakInfo.minutes * 60)
        }
    }
}
