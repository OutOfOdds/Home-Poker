import SwiftUI

struct SettingsView: View {
    @AppStorage("sessionListShowDetails") private var showSessionListDetails = true

    var body: some View {
        Form {
            Section {
                Toggle("Показывать подробности", isOn: $showSessionListDetails)
            }
            header: {
                Text("Список сессий")
            }
            footer: {
                Text("Когда выключено — в списке отображается только название и дата последней игры.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
