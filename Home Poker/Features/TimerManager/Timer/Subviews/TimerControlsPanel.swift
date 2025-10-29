import SwiftUI

/// Панель управления таймером
struct TimerControlsPanel: View {
    @Environment(TimerViewModel.self) private var viewModel

    @Namespace private var namespace
    @State private var showRestartLevelAlert = false

    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            // Кнопка "Назад"
            Button {
                withAnimation {
                    viewModel.skipToPrevious()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            .tint(.indigo)
            .disabled(!viewModel.isRunning)
            .buttonStyle(.bordered)
            
            
            // Кнопка "Старт" или "Пауза/Возобновить"
            playPauseButton
            
            // Кнопка "Сброс" (показывается только когда таймер запущен)
            if viewModel.isRunning {
                resetButton
            }
            
            // Кнопка "Вперёд"
            Button {
                withAnimation {
                    viewModel.skipToNext()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .tint(.indigo)
            .disabled(!viewModel.isRunning)
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .alert("Сбросить текущий уровень?", isPresented: $showRestartLevelAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Сбросить", role: .destructive) {
                withAnimation {
                    viewModel.restartCurrentLevel()
                }
            }
        } message: {
            Text("Таймер текущего уровня будет сброшен на начало.")
        }
    }

    // MARK: - Subviews
    
    @ViewBuilder
    private var playPauseButton: some View {
        if viewModel.canStart {
            // Кнопка "Старт"
            Button {
                withAnimation {
                    viewModel.startTimer()
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title)
            }
            .matchedGeometryEffect(id: "playPauseButton", in: namespace, isSource: true)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if viewModel.isPaused {
            // Кнопка "Возобновить"
            Button {
                withAnimation {
                    viewModel.togglePause()
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title)
            }
            .matchedGeometryEffect(id: "playPauseButton", in: namespace, isSource: true)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if viewModel.isRunning {
            // Кнопка "Пауза"
            Button {
                withAnimation {
                    viewModel.togglePause()
                }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title)
            }
            .matchedGeometryEffect(id: "playPauseButton", in: namespace, isSource: true)
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
    
    private var resetButton: some View {
        Button {
            showRestartLevelAlert = true
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.orange)
    }
}

// MARK: - Preview

#Preview("Начальное состояние (canStart)") {
    let viewModel = PreviewData.timerViewModel(.notStarted)

    VStack {
        TimerControlsPanel()
    }
    .environment(viewModel)
}

#Preview("Идёт уровень") {
    let viewModel = PreviewData.timerViewModel(.running(level: 1))

    VStack {
        TimerControlsPanel()
    }
    .environment(viewModel)
}

#Preview("На паузе") {
    let viewModel = PreviewData.timerViewModel(.paused(level: 1))

    VStack {
        TimerControlsPanel()
    }
    .environment(viewModel)
}
