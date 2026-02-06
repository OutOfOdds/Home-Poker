import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case sessions
    case search
    case timer
}

struct MainView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.modelContext) private var modelContext
    @State private var templateViewModel = TemplateViewModel()
    @State private var timerViewModel: TimerViewModel?
    @State private var selectedTab: AppTab = .sessions
    @State private var didLogDatabaseCounts = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Сессии", systemImage: "list.star", value: .sessions) {
                SessionListView()
            }
            
            if selectedTab == .sessions || selectedTab == .search {
                
                Tab("Поиск", systemImage: "magnifyingglass", value: .search, role: .search) {
                    SessionSearchView()
                }
                
            }
            
            Tab("Таймер", systemImage: "timer", value: .timer) {
                if let timerViewModel {
                    TimerManagerView()
                        .environment(timerViewModel)
                        .environment(templateViewModel)
                } else {
                    ProgressView()
                        .task {
                            // Инициализируем TimerViewModel один раз с сервисами
                            timerViewModel = TimerViewModel(
                                notificationService: notificationService
                            )
                        }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToTimerTab"))) { _ in
            selectedTab = .timer
        }
        .task {
            guard !didLogDatabaseCounts else { return }
            didLogDatabaseCounts = true
            do {
                let expenseCount = try modelContext.fetch(FetchDescriptor<Expense>()).count
                let distributionCount = try modelContext.fetch(FetchDescriptor<ExpenseDistribution>()).count
                print("📊 [App] Expenses: \(expenseCount), Distributions: \(distributionCount)")
            } catch {
                print("❌ [App] Failed to load expense counts: \(error)")
            }
        }
    }
}

#Preview {
    MainView()
        .environment(TimerViewModel())
        .environment(NotificationService())
}
