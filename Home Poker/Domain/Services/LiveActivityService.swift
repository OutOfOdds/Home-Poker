import Foundation
import ActivityKit

// MARK: - Live Activity Service Protocol

protocol LiveActivityServiceProtocol: Sendable {
    /// Запускает Live Activity для таймера турнира
    func startActivity(tournamentName: String, totalLevels: Int) async throws

    /// Обновляет состояние Live Activity
    func updateActivity(contentState: TimerActivityAttributes.ContentState) async

    /// Останавливает Live Activity
    func stopActivity() async

    /// Проверяет, активна ли Live Activity
    var isActivityActive: Bool { get async }
}

// MARK: - Live Activity Service Implementation

@Observable
final class LiveActivityService: LiveActivityServiceProtocol {

    // MARK: - Properties

    private var currentActivity: Activity<TimerActivityAttributes>?

    // MARK: - Public Methods

    /// Запускает Live Activity для таймера турнира
    func startActivity(tournamentName: String, totalLevels: Int) async throws {
        // Проверяем поддержку Live Activities на устройстве
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ [LiveActivityService] Live Activities не поддерживаются на этом устройстве")
            return
        }

        // Останавливаем предыдущую активность если есть
        await stopActivity()

        // Создаем начальное состояние
        let initialState = TimerActivityAttributes.ContentState(
            currentLevelIndex: 0,
            smallBlind: 0,
            bigBlind: 0,
            ante: 0,
            remainingSeconds: 0,
            totalElapsedSeconds: 0,
            levelDurationSeconds: 0,
            isRunning: false,
            isPaused: false,
            isBreak: false,
            breakTitle: nil
        )

        // Создаем атрибуты
        let attributes = TimerActivityAttributes(
            tournamentName: tournamentName,
            totalLevels: totalLevels
        )

        do {
            // Запускаем Live Activity
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            print("✅ [LiveActivityService] Live Activity запущена: \(activity.id)")
        } catch {
            print("❌ [LiveActivityService] Ошибка запуска Live Activity: \(error)")
            throw error
        }
    }

    /// Обновляет состояние Live Activity
    func updateActivity(contentState: TimerActivityAttributes.ContentState) async {
        guard let activity = currentActivity else {
            print("⚠️ [LiveActivityService] Нет активной Live Activity для обновления")
            return
        }

        // Обновляем состояние
        let content = ActivityContent(state: contentState, staleDate: nil)

        await activity.update(content)
    }

    /// Останавливает Live Activity
    func stopActivity() async {
        guard let activity = currentActivity else {
            return
        }

        // Финальное состояние (можно показать "Турнир завершен")
        let finalState = await activity.content.state

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        print("🛑 [LiveActivityService] Live Activity остановлена")
    }

    /// Проверяет, активна ли Live Activity
    var isActivityActive: Bool {
        get async {
            currentActivity != nil
        }
    }
}

// MARK: - Mock Implementation для Preview/Tests

#if DEBUG
final class MockLiveActivityService: LiveActivityServiceProtocol {

    var isActivityActive: Bool {
        get async { _isActive }
    }

    private var _isActive = false

    func startActivity(tournamentName: String, totalLevels: Int) async throws {
        _isActive = true
        print("🧪 [MockLiveActivityService] Activity started: \(tournamentName)")
    }

    func updateActivity(contentState: TimerActivityAttributes.ContentState) async {
        print("🧪 [MockLiveActivityService] Activity updated: Level \(contentState.currentLevelIndex + 1)")
    }

    func stopActivity() async {
        _isActive = false
        print("🧪 [MockLiveActivityService] Activity stopped")
    }
}
#endif
