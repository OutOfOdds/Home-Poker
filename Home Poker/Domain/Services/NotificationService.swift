import UserNotifications
import Foundation
import Observation
import UIKit

protocol NotificationServiceProtocol: Sendable {
    /// Запрашивает разрешение на уведомления
    func requestAuthorization() async -> Bool

    /// Планирует уведомление о смене уровня блайндов (немедленно, через 1 сек)
    func scheduleBlindLevelNotification(
        levelIndex: Int,
        item: LevelItem
    ) async throws

    /// Планирует уведомление с указанной задержкой (для pre-scheduling)
    func scheduleBlindLevelNotificationWithDelay(
        levelIndex: Int,
        item: LevelItem,
        delay: TimeInterval
    ) async throws

    /// Планирует уведомление о завершении турнира (немедленно, через 1 сек)
    func scheduleTournamentCompletedNotification() async throws

    /// Планирует уведомление о завершении турнира с указанной задержкой
    func scheduleTournamentCompletedNotificationWithDelay(delay: TimeInterval) async throws

    /// Отменяет все запланированные уведомления
    func cancelAllNotifications() async

    /// Проверяет статус разрешений
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
}

// MARK: - Notification Service Implementation

@Observable
final class NotificationService: NSObject, NotificationServiceProtocol {

    // MARK: - Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // Track if delegate was set (for debugging)
    private(set) var isDelegateSet = false

    // MARK: - Constants

    private enum Constants {
        static let categoryIdentifier = "BLIND_LEVEL_CHANGE"
        static let notificationPrefix = "blind_level_"
        static let tournamentCompletedPrefix = "tournament_completed_"
        static let switchToTimerTabNotification = "SwitchToTimerTab"
        static let threadIdentifier = "blind_level_changes"
        static let immediateDelay: TimeInterval = 1
    }

    // MARK: - Initialization

    override init() {
        super.init()
        notificationCenter.delegate = self
        isDelegateSet = true
        print("✅ [NotificationService] Delegate registered in init")
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound]
            )

            print("🔔 [NotificationService] Authorization granted: \(granted)")

            if granted {
                await registerCategories()
                print("✅ [NotificationService] Categories registered")
            } else {
                print("❌ [NotificationService] Authorization denied")
            }

            return granted
        } catch {
            print("❌ [NotificationService] Error requesting authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Scheduling

    func scheduleBlindLevelNotification(
        levelIndex: Int,
        item: LevelItem
    ) async throws {
        try await scheduleBlindLevel(
            levelIndex: levelIndex,
            item: item,
            delay: Constants.immediateDelay
        )
    }

    func scheduleBlindLevelNotificationWithDelay(
        levelIndex: Int,
        item: LevelItem,
        delay: TimeInterval
    ) async throws {
        try await scheduleBlindLevel(
            levelIndex: levelIndex,
            item: item,
            delay: delay
        )
    }

    func scheduleTournamentCompletedNotification() async throws {
        try await scheduleTournamentCompleted(delay: Constants.immediateDelay)
    }

    func scheduleTournamentCompletedNotificationWithDelay(delay: TimeInterval) async throws {
        try await scheduleTournamentCompleted(delay: delay)
    }

    // MARK: - Cancellation

    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()

        // Сбрасываем badge на иконке приложения
        if #available(iOS 17.0, *) {
            try? await notificationCenter.setBadgeCount(0)
        } else {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }

        print("🗑 [NotificationService] All notifications cleared")
    }

    // MARK: - Private Helpers

    private func registerCategories() async {
        let category = UNNotificationCategory(
            identifier: Constants.categoryIdentifier,
            actions: [],
            intentIdentifiers: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Private Scheduling Helpers

    /// Проверяет авторизацию и возвращает true если разрешено
    private func ensureAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        guard settings.authorizationStatus == .authorized else {
            print("❌ [NotificationService] Notifications not authorized")
            return false
        }

        return true
    }

    /// Создает контент для уведомления о смене уровня блайндов
    private func makeBlindLevelContent(levelIndex: Int, item: LevelItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        switch item {
        case .blinds(let level):
            content.title = "Уровень \(levelIndex + 1)"

            if level.ante > 0 {
                content.body = "Блайнды: \(level.smallBlind)/\(level.bigBlind), анте \(level.ante)"
            } else {
                content.body = "Блайнды: \(level.smallBlind)/\(level.bigBlind)"
            }

        case .break(let breakInfo):
            content.title = breakInfo.title
            content.body = "Длительность: \(breakInfo.minutes) мин"
        }

        content.categoryIdentifier = Constants.categoryIdentifier
        content.sound = .default
        content.threadIdentifier = Constants.threadIdentifier

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        return content
    }

    /// Создает контент для уведомления о завершении турнира
    private func makeTournamentCompletedContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Турнир завершен"
        content.body = "Все уровни блайндов пройдены"
        content.categoryIdentifier = Constants.categoryIdentifier
        content.sound = .default

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        return content
    }

    /// Планирует уведомление с заданным контентом, идентификатором и задержкой
    private func scheduleNotification(
        content: UNMutableNotificationContent,
        identifier: String,
        delay: TimeInterval
    ) async throws {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)

            if delay == Constants.immediateDelay {
                print("📬 [NotificationService] Scheduled: \(content.title) - \(content.body)")
            } else {
                print("📅 [NotificationService] Scheduled in \(Int(delay))s: \(content.title)")
            }

            #if DEBUG
            let pending = await notificationCenter.pendingNotificationRequests()
            print("📋 [NotificationService] Pending notifications count: \(pending.count)")
            #endif
        } catch {
            print("❌ [NotificationService] Failed to schedule: \(error)")
            throw error
        }
    }

    /// Планирует уведомление о смене уровня с заданной задержкой
    private func scheduleBlindLevel(
        levelIndex: Int,
        item: LevelItem,
        delay: TimeInterval
    ) async throws {
        guard await ensureAuthorized() else { return }

        let content = makeBlindLevelContent(levelIndex: levelIndex, item: item)
        let identifier = "\(Constants.notificationPrefix)\(levelIndex)_\(UUID().uuidString)"

        try await scheduleNotification(
            content: content,
            identifier: identifier,
            delay: delay
        )
    }

    /// Планирует уведомление о завершении турнира с заданной задержкой
    private func scheduleTournamentCompleted(delay: TimeInterval) async throws {
        guard await ensureAuthorized() else { return }

        let content = makeTournamentCompletedContent()
        let identifier = "\(Constants.tournamentCompletedPrefix)\(UUID().uuidString)"

        try await scheduleNotification(
            content: content,
            identifier: identifier,
            delay: delay
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Показывать уведомления даже когда приложение на переднем плане
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [Delegate] willPresent called for: \(notification.request.content.title)")
        print("📱 [Delegate] Showing banner and sound")

        // Показываем banner и sound даже в foreground (без badge)
        completionHandler([.banner, .sound])
    }

    /// Вызывается когда пользователь нажимает на уведомление
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("✅ [Delegate] User tapped notification: \(response.notification.request.content.title)")

        // Переключаемся на таб таймера при нажатии на уведомление
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name(Constants.switchToTimerTabNotification),
                object: nil
            )
        }

        completionHandler()
    }
}
