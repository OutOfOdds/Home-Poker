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
                    do {
                        try Tips.resetDatastore()
                        try Tips.configure()
                    }
                    catch {
                        print("Error initializing TipKit \(error.localizedDescription)")
                    }
                }
                .onAppear {
                    print(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
                }
        }
        .modelContainer(for: [Player.self, Session.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self])
    }
}
