import SwiftUI
import SwiftData


@main
struct Home_PokerApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
        }
        .modelContainer(for: [Player.self, Session.self, PlayerTransaction.self, Expense.self])
    }
}
