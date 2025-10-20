import SwiftUI
import SwiftData


@main
struct Home_PokerApp: App {
    @State var sessionDetailVM = SessionDetailViewModel()
    var body: some Scene {
        WindowGroup {
            SessionListView()
                .environment(sessionDetailVM)
        }
        .modelContainer(for: [Player.self, Session.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self])
    }
}
