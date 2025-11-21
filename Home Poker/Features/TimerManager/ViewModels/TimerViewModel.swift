import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class TimerViewModel {

    private let timerService: SessionTimerProtocol
    private let notificationService: NotificationServiceProtocol
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

    // MARK: - Constants

    private enum Constants {
        static let timerUpdateInterval: Duration = .seconds(1)
        static let persistentStateKey = "timerPersistentState"
    }

    // MARK: - Persistent State

    private struct PersistentTimerState: Codable {
        let absoluteStartDate: Date?
        let pausedAt: Date?
        let accumulatedPausedTime: TimeInterval
        let currentIndex: Int
        let manualTimeOffset: TimeInterval
        let itemsJSON: Data // Храним items как JSON
    }

    // MARK: - Initialization

    init(
        timerService: SessionTimerProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.timerService = timerService ?? TimerService()
        self.notificationService = notificationService ?? NotificationService()

        // Восстанавливаем состояние таймера если оно было сохранено
        restoreTimerState()
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

        // Запуск таймера (только для UI обновлений в foreground)
        startTicking()

        // Немедленный расчёт состояния
        tick()

        // Сохраняем начальное состояние
        saveTimerState()
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

        // Сохраняем состояние паузы
        saveTimerState()
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

        // Обновляем состояние для возобновления
        if let state = currentState {
            let resumedState = TimerState(
                currentLevelIndex: state.currentLevelIndex,
                currentItem: state.currentItem,
                elapsedTimeInLevel: state.elapsedTimeInLevel,
                remainingTimeInLevel: state.remainingTimeInLevel,
                totalElapsedTime: state.totalElapsedTime,
                isRunning: true,
                isPaused: false
            )
            currentState = resumedState
        }

        // Возобновляем тикание
        startTicking()
        tick()

        // Сохраняем возобновленное состояние
        saveTimerState()
    }

    /// Останавливает таймер полностью
    func stopTimer() {
        stopTicking()

        // Сразу очищаем состояние (синхронно для UI)
        absoluteStartDate = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        manualTimeOffset = 0
        currentIndex = 0
        currentState = nil
        // НЕ очищаем items - структура блайндов должна сохраняться

        // Очищаем сохраненное состояние
        clearSavedState()

        // Асинхронно отменяем уведомления
        Task { @MainActor in
            await notificationService.cancelAllNotifications()
        }
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

        // ВАЖНО: Перепланируем уведомления после ручного skip
        // Временная шкала изменилась, старые уведомления неактуальны
        if notificationsEnabled && !wasPaused {
            rescheduleNotificationsAfterPause()
            print("🔔 [TimerViewModel] Rescheduled notifications after manual jump to level \(index)")
        }

        // Сохраняем состояние после ручного skip
        saveTimerState()
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

            // Планируем уведомление о завершении турнира после всех уровней
            try? await notificationService.scheduleTournamentCompletedNotificationWithDelay(
                delay: cumulativeSeconds
            )

            print("📅 [TimerViewModel] Scheduled \(items.count - 1) level notifications + tournament completion")
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

            // Планируем уведомление о завершении турнира, если оно еще не наступило
            let tournamentEndTime = cumulativeSeconds
            if tournamentEndTime > effectiveElapsed {
                let delay = tournamentEndTime - effectiveElapsed
                try? await notificationService.scheduleTournamentCompletedNotificationWithDelay(
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
            let oldIndex = currentIndex
            currentIndex = levelIndex
            print("🔄 [TimerViewModel] Level changed: \(oldIndex) → \(levelIndex)")
            // Уведомления уже запланированы заранее в scheduleAllNotificationsUpfront()

            // Сохраняем состояние при смене уровня
            saveTimerState()
        }

        let currentItem = items[currentIndex]
        let levelDuration = timerService.durationInSeconds(for: currentItem)
        let remainingInLevel = max(0, levelDuration - elapsedInLevel)

        // Проверяем завершение турнира: последний уровень и время истекло
        let isLastLevel = currentIndex == items.count - 1
        if isLastLevel && remainingInLevel <= 0 {
            print("🏁 [TimerViewModel] All levels completed - stopping timer")
            // Уведомление о завершении уже запланировано заранее в scheduleAllNotificationsUpfront()
            stopTimer()
            return
        }

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

    // MARK: - Persistence

    /// Сохраняет текущее состояние таймера в UserDefaults
    private func saveTimerState() {
        // Сохраняем только если таймер реально запущен
        guard let absoluteStartDate = absoluteStartDate, isRunning else {
            // Если таймер не запущен, очищаем сохраненное состояние
            clearSavedState()
            return
        }

        do {
            // Сериализуем items в JSON
            let itemsData = try JSONEncoder().encode(items)

            let state = PersistentTimerState(
                absoluteStartDate: absoluteStartDate,
                pausedAt: pausedAt,
                accumulatedPausedTime: accumulatedPausedTime,
                currentIndex: currentIndex,
                manualTimeOffset: manualTimeOffset,
                itemsJSON: itemsData
            )

            // Кодируем в JSON и сохраняем
            let encoded = try JSONEncoder().encode(state)
            UserDefaults.standard.set(encoded, forKey: Constants.persistentStateKey)

            print("💾 [TimerViewModel] Timer state saved")
        } catch {
            print("❌ [TimerViewModel] Failed to save timer state: \(error)")
        }
    }

    /// Восстанавливает состояние таймера из UserDefaults
    private func restoreTimerState() {
        guard let data = UserDefaults.standard.data(forKey: Constants.persistentStateKey) else {
            print("ℹ️ [TimerViewModel] No saved timer state found")
            return
        }

        do {
            // Декодируем состояние
            let state = try JSONDecoder().decode(PersistentTimerState.self, from: data)

            // Десериализуем items
            let restoredItems = try JSONDecoder().decode([LevelItem].self, from: state.itemsJSON)

            // Проверяем, не устарело ли состояние (например, прошло более 24 часов)
            if let absoluteStartDate = state.absoluteStartDate {
                let hoursSinceStart = Date().timeIntervalSince(absoluteStartDate) / 3600

                if hoursSinceStart > 24 {
                    print("⏰ [TimerViewModel] Saved state is too old (>24h), clearing")
                    clearSavedState()
                    return
                }
            }

            // Восстанавливаем состояние
            self.items = restoredItems
            self.absoluteStartDate = state.absoluteStartDate
            self.pausedAt = state.pausedAt
            self.accumulatedPausedTime = state.accumulatedPausedTime
            self.currentIndex = state.currentIndex
            self.manualTimeOffset = state.manualTimeOffset
            self.isConfigured = !items.isEmpty
            self.showConfigForm = false

            // Если таймер был активен, восстанавливаем его работу
            if let _ = state.absoluteStartDate {
                // Если таймер был на паузе, НЕ запускаем tick автоматически
                if state.pausedAt != nil {
                    print("▶️ [TimerViewModel] Timer restored in PAUSED state")
                    // Просто вычисляем текущее состояние для UI
                    tick()
                } else {
                    // Таймер был активен - возобновляем
                    print("▶️ [TimerViewModel] Timer restored and RESUMED")
                    startTicking()
                    tick()

                    // Перепланируем уведомления
                    if notificationsEnabled {
                        rescheduleNotificationsAfterPause()
                    }
                }
            }

            print("✅ [TimerViewModel] Timer state restored successfully")
        } catch {
            print("❌ [TimerViewModel] Failed to restore timer state: \(error)")
            // Очищаем поврежденное состояние
            clearSavedState()
        }
    }

    /// Очищает сохраненное состояние
    private func clearSavedState() {
        UserDefaults.standard.removeObject(forKey: Constants.persistentStateKey)
        print("🗑️ [TimerViewModel] Saved timer state cleared")
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
