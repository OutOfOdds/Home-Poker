import SwiftUI

enum AppTab: Hashable {
    case sessions
    case timer
}

struct MainView: View {
    @Environment(NotificationService.self) private var notificationService
    @State private var templateViewModel = TemplateViewModel()
    @State private var timerViewModel: TimerViewModel?
    @State private var selectedTab: AppTab = .sessions

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Сессии", systemImage: "list.star", value: .sessions) {
                SessionListView()
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
    }
}

#Preview {
    MainView()
        .environment(TimerViewModel())
}
