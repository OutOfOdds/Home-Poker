import Foundation
import SwiftUI
import Observation

@Observable
final class TimerViewModel {

    private let timerService = SessionTimerService()
    private var timer: Timer?
    private var absoluteStartDate: Date?
    private var pausedAt: Date?
    private var accumulatedPausedTime: TimeInterval = 0
    private var currentIndex: Int = 0
    private var manualTimeOffset: TimeInterval = 0

    var items: [LevelItem] = []
    var isConfigured: Bool = false
    var showConfigForm: Bool = true
    var currentState: TimerState?

    // MARK: - Конфигурация

    /// Загружает турнир с шаблоном (без автоматического запуска)
    func startFromTemplate(_ template: TournamentTemplate) {
        items = template.levels.map { .blinds($0) }
        isConfigured = !items.isEmpty

        // Скрываем форму выбора шаблона
        showConfigForm = false

        // НЕ запускаем таймер автоматически - пользователь сам нажмёт "Старт"
    }

    /// Сбрасывает турнир и возвращает к форме настройки
    func resetToConfig() {
        stopTimer()
        items = []
        isConfigured = false
        showConfigForm = true
    }

    // MARK: - Контроль таймера

    /// Запускает таймер с указанной структурой уровней
    func startTimer() {
        guard !items.isEmpty else { return }

        // Сброс состояния
        stopTimer()

        self.absoluteStartDate = Date()
        self.currentIndex = 0
        self.accumulatedPausedTime = 0
        self.manualTimeOffset = 0
        self.pausedAt = nil

        // Запуск таймера
        startTicking()

        // Немедленный расчёт состояния
        tick()
    }

    /// Ставит таймер на паузу
    func pause() {
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

    /// Возобновляет таймер после паузы
    func resume() {
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

    /// Останавливает таймер полностью
    func stopTimer() {
        stopTicking()

        absoluteStartDate = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        manualTimeOffset = 0
        currentIndex = 0
        currentState = nil
        // НЕ очищаем items - структура блайндов должна сохраняться
    }

    /// Переключает паузу/возобновление
    func togglePause() {
        guard let state = currentState else { return }

        if state.isPaused {
            resume()
        } else {
            pause()
        }
    }

    /// Переходит к следующему уровню
    func skipToNext() {
        guard currentIndex < items.count - 1 else { return }
        jumpToLevel(at: currentIndex + 1)
    }

    /// Возвращается к предыдущему уровню
    func skipToPrevious() {
        guard currentIndex > 0 else { return }
        jumpToLevel(at: currentIndex - 1)
    }

    /// Переходит к конкретному уровню по индексу
    func jumpToLevel(at index: Int) {
        guard items.indices.contains(index) else { return }
        guard let absoluteStartDate = absoluteStartDate else { return }

        let wasPaused = currentState?.isPaused ?? false

        // Рассчитываем время начала целевого уровня
        let targetLevelStartTime = timerService.calculateLevelStartTime(for: index, items: items)

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

    /// Перезапускает текущий уровень с начала
    func restartCurrentLevel() {
        jumpToLevel(at: currentIndex)
    }

    // MARK: - Методы таймера

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

        // Определяем текущий уровень и время в нём (используем timerService)
        let (levelIndex, elapsedInLevel) = timerService.calculateCurrentLevel(
            effectiveElapsed: effectiveElapsed,
            items: items
        )

        // Если автоматически перешли на новый уровень
        if levelIndex != currentIndex {
            currentIndex = levelIndex
        }

        // Если дошли до конца всех уровней
        guard items.indices.contains(currentIndex) else {
            stopTimer()
            return
        }

        let currentItem = items[currentIndex]
        let levelDuration = timerService.durationInSeconds(for: currentItem)
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

    // MARK: - Редактирование уровня блайндов

    /// Обновляет уровень (только ручное редактирование, без автоматических пересчётов)
    func updateLevel(at index: Int, smallBlind: Int, bigBlind: Int, ante: Int) {
        guard items.indices.contains(index) else { return }
        guard case .blinds(let level) = items[index] else { return }

        // Создаём обновлённый уровень
        let updatedLevel = BlindLevel(
            index: level.index,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            ante: ante,
            minutes: level.minutes
        )
        items[index] = .blinds(updatedLevel)
    }


    // MARK: - Computed Properties

    var isRunning: Bool {
        currentState?.isRunning ?? false
    }

    var isPaused: Bool {
        currentState?.isPaused ?? false
    }

    var canStart: Bool {
        isConfigured && !isRunning
    }

    var canPause: Bool {
        isRunning && !isPaused
    }

    var canResume: Bool {
        isRunning && isPaused
    }
}
