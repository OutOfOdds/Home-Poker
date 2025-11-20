import SwiftUI
import SwiftData
import TipKit
import UserNotifications

@main
struct Home_PokerApp: App {
    @State private var notificationService = NotificationService()
    @State var sessionDetailVM = SessionDetailViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(notificationService)
                .environment(sessionDetailVM)
                .task {
                    // Инициализация TipKit
                    do {
                        try Tips.resetDatastore()
                        try Tips.configure()
                    }
                    catch {
                        print("Error initializing TipKit \(error.localizedDescription)")
                    }

                    // Запрос разрешений на уведомления
                    let granted = await notificationService.requestAuthorization()
                    print("🔔 [App] Notification authorization: \(granted)")
                    print("🔔 [App] Delegate is set: \(notificationService.isDelegateSet)")

                    // Проверяем что delegate действительно установлен в системе
                    let systemDelegate = UNUserNotificationCenter.current().delegate
                    print("🔔 [App] System delegate is set: \(systemDelegate != nil)")
                }
                .onAppear {
                    print(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
                }
        }
        .modelContainer(for: [
            Player.self,
            Session.self,
            PlayerChipTransaction.self,
            Expense.self,
            ExpenseDistribution.self,
            SessionBank.self,
            SessionBankTransaction.self,
            SettlementTransfer.self
        ])
    }
}
