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
