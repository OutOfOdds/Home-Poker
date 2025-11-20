import SwiftUI

struct MainView: View {
    @Environment(NotificationService.self) private var notificationService
    @State private var templateViewModel = TemplateViewModel()

    var body: some View {
        TabView {
            Tab("Сессии", systemImage: "list.star") {
                SessionListView()
            }
            Tab("Таймер", systemImage: "timer") {
                @Bindable var notificationService = notificationService
                TimerManagerView()
                    .environment(TimerViewModel(notificationService: notificationService))
                    .environment(templateViewModel)
            }
        }
    }
}

#Preview {
    MainView()
}
