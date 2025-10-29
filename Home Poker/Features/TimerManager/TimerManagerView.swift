import SwiftUI

struct TimerManagerView: View {
    @Environment(TimerViewModel.self) private var timerViewModel
    @Environment(TemplateViewModel.self) private var templateViewModel

    @State private var showBackToTemplatesAlert = false
    
    var body: some View {
        Group {
            if timerViewModel.showConfigForm {
                NavigationStack {
                    TemplatePickerView()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                NavigationStack {
                    timerContent
                }
                .alert("Вернуться к выбору шаблона?", isPresented: $showBackToTemplatesAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Вернуться", role: .destructive) {
                        withAnimation {
                            timerViewModel.resetToConfig()
                        }
                    }
                } message: {
                    Text("Турнир будет остановлен, и вы вернётесь к выбору шаблона.")
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
    }
}


private extension TimerManagerView {
    var timerContent: some View {
        Form {
            TimerView()
        }
        .navigationTitle("Таймер")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showBackToTemplatesAlert = true
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Таймер") {
    TabView {
        Tab("Таймер", systemImage: "timer") {
            TimerManagerView()
                .environment(PreviewData.timerViewModel(.notStarted))
                .environment(TemplateViewModel())
        }
    }
}
