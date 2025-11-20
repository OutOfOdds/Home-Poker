import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class TimerViewModel {

    private let timerService: SessionTimerProtocol
    private let notificationService: NotificationServiceProtocol
    private let liveActivityService: LiveActivityServiceProtocol
    private var timerTask: Task<Void, Never>?
    private var absoluteStartDate: Date?
    private var pausedAt: Date?
    private var accumulatedPausedTime: TimeInterval = 0
    private var currentIndex: Int = 0
    private var manualTimeOffset: TimeInterval = 0

    var items: [LevelItem] = []
    var isConfigured: Bool = false
    var showConfigForm: Bool = true
    var currentState: TimerState?

    @ObservationIgnored
    @AppStorage("timerNotificationsEnabled") private var notificationsEnabled = true

    @ObservationIgnored
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled = true

    // MARK: - Constants

    private enum Constants {
        static let timerUpdateInterval: Duration = .seconds(1)
    }

    // MARK: - Initialization

    init(
        timerService: SessionTimerProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        liveActivityService: LiveActivityServiceProtocol? = nil
    ) {
        self.timerService = timerService ?? TimerService()
        self.notificationService = notificationService ?? NotificationService()
        self.liveActivityService = liveActivityService ?? LiveActivityService()
    }

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

        // Запланировать ВСЕ уведомления заранее (для работы в background)
        if notificationsEnabled {
            scheduleAllNotificationsUpfront()
        }

        // Запустить Live Activity
        if liveActivitiesEnabled {
            Task {
                try? await liveActivityService.startActivity(
                    tournamentName: "Poker Tournament",
                    totalLevels: items.count
                )
            }
        }

        // Запуск таймера (только для UI обновлений в foreground)
        startTicking()

        // Немедленный расчёт состояния
        tick()
    }

    /// Ставит таймер на паузу
    func pause() {
        guard currentState?.isRunning == true, currentState?.isPaused == false else { return }

        pausedAt = Date()
        stopTicking()

        // Отменяем все запланированные уведомления (они станут неактуальны)
        Task { @MainActor in
            await notificationService.cancelAllNotifications()
            print("⏸️ [TimerViewModel] Paused - cancelled all notifications")
        }

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

        // Пересчитываем и планируем уведомления заново с учётом прошедшего времени
        if notificationsEnabled {
            rescheduleNotificationsAfterPause()
        }

        // Возобновляем тикание
        startTicking()
        tick()
    }

    /// Останавливает таймер полностью
    func stopTimer() {
        stopTicking()

        // Отменить все запланированные уведомления
        Task {
            await notificationService.cancelAllNotifications()

            // Остановить Live Activity
            if liveActivitiesEnabled {
                await liveActivityService.stopActivity()
            }
        }

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

    // MARK: - Timer Implementation (Modern Task-based)

    private func startTicking() {
        stopTicking()

        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Constants.timerUpdateInterval)

                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Планирует ВСЕ уведомления заранее для работы в background
    private func scheduleAllNotificationsUpfront() {
        Task { @MainActor in
            print("📅 [TimerViewModel] Pre-scheduling all notifications...")

            // Отменяем предыдущие
            await notificationService.cancelAllNotifications()

            var cumulativeSeconds: TimeInterval = 0

            // Проходим по всем уровням и планируем уведомления
            for (index, item) in items.enumerated() {
                // Пропускаем первый уровень (он стартует сразу)
                if index == 0 {
                    // Добавляем длительность первого уровня к cumulative
                    switch item {
                    case .blinds(let level):
                        cumulativeSeconds += TimeInterval(level.minutes * 60)
                    case .break(let breakInfo):
                        cumulativeSeconds += TimeInterval(breakInfo.minutes * 60)
                    }
                    continue
                }

                // Планируем уведомление для этого уровня
                // timeInterval = время с момента старта таймера
                try? await notificationService.scheduleBlindLevelNotificationWithDelay(
                    levelIndex: index,
                    item: item,
                    delay: cumulativeSeconds
                )

                // Добавляем длительность текущего уровня
                switch item {
                case .blinds(let level):
                    cumulativeSeconds += TimeInterval(level.minutes * 60)
                case .break(let breakInfo):
                    cumulativeSeconds += TimeInterval(breakInfo.minutes * 60)
                }
            }

            print("📅 [TimerViewModel] Scheduled \(items.count - 1) notifications")
        }
    }

    /// Пересчитывает и планирует уведомления после паузы
    private func rescheduleNotificationsAfterPause() {
        guard let absoluteStartDate = absoluteStartDate else { return }

        Task { @MainActor in
            print("▶️ [TimerViewModel] Rescheduling notifications after pause...")

            await notificationService.cancelAllNotifications()

            // Вычисляем эффективное прошедшее время
            let now = Date()
            let effectiveElapsed = now.timeIntervalSince(absoluteStartDate) - accumulatedPausedTime - manualTimeOffset

            var cumulativeSeconds: TimeInterval = 0

            // Планируем только будущие уведомления
            for (index, item) in items.enumerated() {
                // Вычисляем когда должен начаться этот уровень
                let levelStartTime = cumulativeSeconds

                // Добавляем длительность к cumulative
                switch item {
                case .blinds(let level):
                    cumulativeSeconds += TimeInterval(level.minutes * 60)
                case .break(let breakInfo):
                    cumulativeSeconds += TimeInterval(breakInfo.minutes * 60)
                }

                // Пропускаем уровни которые уже прошли
                if levelStartTime <= effectiveElapsed {
                    continue
                }

                // Планируем уведомление для будущего уровня
                let delay = levelStartTime - effectiveElapsed
                try? await notificationService.scheduleBlindLevelNotificationWithDelay(
                    levelIndex: index,
                    item: item,
                    delay: delay
                )
            }

            print("▶️ [TimerViewModel] Rescheduled notifications after pause")
        }
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
            // Уведомления уже запланированы заранее в scheduleAllNotificationsUpfront()
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

        // Обновляем Live Activity
        if liveActivitiesEnabled {
            updateLiveActivity(state: state, currentItem: currentItem, levelDuration: levelDuration)
        }
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

    // MARK: - Live Activity Helpers

    /// Обновляет Live Activity с текущим состоянием таймера
    private func updateLiveActivity(state: TimerState, currentItem: LevelItem, levelDuration: TimeInterval) {
        Task {
            // Извлекаем данные из currentItem
            let (smallBlind, bigBlind, ante, isBreak, breakTitle): (Int, Int, Int, Bool, String?)

            switch currentItem {
            case .blinds(let level):
                smallBlind = level.smallBlind
                bigBlind = level.bigBlind
                ante = level.ante
                isBreak = false
                breakTitle = nil

            case .break(let breakInfo):
                smallBlind = 0
                bigBlind = 0
                ante = 0
                isBreak = true
                breakTitle = breakInfo.title
            }

            // Вычисляем время окончания текущего уровня
            let levelEndDate = Date().addingTimeInterval(state.remainingTimeInLevel)

            // Создаём ContentState для Live Activity
            let contentState = TimerActivityAttributes.ContentState(
                currentLevelIndex: state.currentLevelIndex,
                smallBlind: smallBlind,
                bigBlind: bigBlind,
                ante: ante,
                remainingSeconds: state.remainingTimeInLevel,
                levelEndDate: levelEndDate,
                totalElapsedSeconds: state.totalElapsedTime,
                levelDurationSeconds: levelDuration,
                isRunning: state.isRunning,
                isPaused: state.isPaused,
                isBreak: isBreak,
                breakTitle: breakTitle
            )

            // Обновляем Live Activity
            await liveActivityService.updateActivity(contentState: contentState)
        }
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
