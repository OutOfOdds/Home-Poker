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
        // Проверяем статус разрешений
        let settings = await notificationCenter.notificationSettings()
        print("🔍 [NotificationService] Authorization status: \(settings.authorizationStatus.rawValue)")
        print("🔍 [NotificationService] Alert setting: \(settings.alertSetting.rawValue)")

        guard settings.authorizationStatus == .authorized else {
            print("❌ [NotificationService] Notifications not authorized, status: \(settings.authorizationStatus.rawValue)")
            return
        }

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

        // Критично для показа на lock screen
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Группировка уведомлений
        content.threadIdentifier = "blind_level_changes"

        // Немедленная доставка (минимум 1 секунда для надежности)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )

        // Уникальный identifier чтобы избежать коллизий
        let identifier = "\(Constants.notificationPrefix)\(levelIndex)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("📬 [NotificationService] Scheduled: \(content.title) - \(content.body)")

            // Проверяем pending notifications
            let pending = await notificationCenter.pendingNotificationRequests()
            print("📋 [NotificationService] Pending notifications count: \(pending.count)")
        } catch {
            print("❌ [NotificationService] Failed to schedule: \(error)")
            throw error
        }
    }

    /// Планирует уведомление с указанной задержкой от текущего момента (для pre-scheduling)
    func scheduleBlindLevelNotificationWithDelay(
        levelIndex: Int,
        item: LevelItem,
        delay: TimeInterval
    ) async throws {
        // Проверяем статус разрешений
        let settings = await notificationCenter.notificationSettings()

        guard settings.authorizationStatus == .authorized else {
            print("❌ [NotificationService] Notifications not authorized")
            return
        }

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

        // Планируем с указанной задержкой
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )

        let identifier = "\(Constants.notificationPrefix)\(levelIndex)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("📅 [NotificationService] Scheduled level \(levelIndex + 1) in \(Int(delay))s: \(content.title)")
        } catch {
            print("❌ [NotificationService] Failed to schedule: \(error)")
            throw error
        }
    }

    /// Планирует уведомление о завершении турнира
    func scheduleTournamentCompletedNotification() async throws {
        // Проверяем статус разрешений
        let settings = await notificationCenter.notificationSettings()

        guard settings.authorizationStatus == .authorized else {
            print("❌ [NotificationService] Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "🏆 Турнир завершен"
        content.body = "Все уровни блайндов пройдены"
        content.categoryIdentifier = Constants.categoryIdentifier
        content.sound = .default

        // Критично для показа на lock screen
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Немедленная доставка (минимум 1 секунда для надежности)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )

        let identifier = "tournament_completed_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("🏆 [NotificationService] Scheduled tournament completion notification")
        } catch {
            print("❌ [NotificationService] Failed to schedule completion: \(error)")
            throw error
        }
    }

    /// Планирует уведомление о завершении турнира с указанной задержкой
    func scheduleTournamentCompletedNotificationWithDelay(delay: TimeInterval) async throws {
        // Проверяем статус разрешений
        let settings = await notificationCenter.notificationSettings()

        guard settings.authorizationStatus == .authorized else {
            print("❌ [NotificationService] Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "🏆 Турнир завершен"
        content.body = "Все уровни блайндов пройдены"
        content.categoryIdentifier = Constants.categoryIdentifier
        content.sound = .default

        // Критично для показа на lock screen
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Планируем с указанной задержкой
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )

        let identifier = "tournament_completed_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("🏆 [NotificationService] Scheduled tournament completion in \(Int(delay))s")
        } catch {
            print("❌ [NotificationService] Failed to schedule completion: \(error)")
            throw error
        }
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
            NotificationCenter.default.post(name: Notification.Name("SwitchToTimerTab"), object: nil)
        }

        completionHandler()
    }
}
