import SwiftUI
import SwiftData
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
                    let granted = await notificationService.requestAuthorization()
                    print("🔔 [App] Notification authorization: \(granted)")
                }
        }
        .modelContainer(for: [
            Club.self,
            ClubMember.self,
            ClubMemberStats.self,
            ClubMemberSessionStats.self,
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
