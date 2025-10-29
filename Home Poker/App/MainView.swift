import SwiftUI

struct MainView: View {
    @State private var timerViewModel = TimerViewModel()
    @State private var templateViewModel = TemplateViewModel()
    
    var body: some View {
        TabView {
            Tab("Сессии", systemImage: "list.star") {
                SessionListView()
            }
            Tab("Таймер", systemImage: "timer") {
                TimerManagerView()
                    .environment(timerViewModel)
                    .environment(templateViewModel)
            }
        }
    }
}

#Preview {
    MainView()
}
