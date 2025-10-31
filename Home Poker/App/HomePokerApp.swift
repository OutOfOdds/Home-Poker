import SwiftUI
import SwiftData
import TipKit

@main
struct Home_PokerApp: App {
    @State var sessionDetailVM = SessionDetailViewModel()
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(sessionDetailVM)
                .task {
                    try? Tips.configure()
                }
                .onAppear {
                    print(
    FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!
)
                }
        }
        .modelContainer(for: [Player.self, Session.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self])
    }
}
