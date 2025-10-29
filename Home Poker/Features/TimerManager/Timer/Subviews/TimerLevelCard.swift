import SwiftUI

struct TimerLevelCard: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        timerDisplay
            .frame(maxWidth: .infinity, alignment: .center)
        if case .blinds = viewModel.currentState?.currentItem {
            HStack {
                VStack(spacing: 8) {
                    Text(levelTitle)
                        .font(.title2)
                        .fontWeight(.medium)
                        .monospaced()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text(blindsText)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)

                    timerStatusIndicator(isPaused: viewModel.currentState?.isPaused ?? true)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    
                }
            }
        } else if case .break = viewModel.currentState?.currentItem {
            HStack {
                Image(systemName: "cup.and.heat.waves.fill")
                Text(levelTitle)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.purple.opacity(0.2))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    @ViewBuilder
    private var timerDisplay: some View {
        if let state = viewModel.currentState {
            // Таймер запущен - показываем оставшееся время
            Text(state.remainingTimeInLevel.formattedTime)
                .font(.system(size: 96, weight: .bold, design: .monospaced))
                .foregroundStyle(state.isPaused ? .secondary : .primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        } else if let firstItem = viewModel.items.first {
            // Таймер не запущен - показываем длительность первого уровня
            let minutes = firstItem.durationMinutes
            Text(TimeInterval(minutes * 60).formattedTime)
                .font(.system(size: 96, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private func timerStatusIndicator(isPaused: Bool) -> some View {
        let text = isPaused ? "ПАУЗА" : "ИДЁТ"
        let color: Color = isPaused ? .orange : .green
        
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
    
    private var levelTitle: String {
        if let state = viewModel.currentState {
            return state.currentItem.title
        } else if let firstItem = viewModel.items.first {
            return firstItem.title
        }
        return ""
    }

    private var blindsText: String {
        if let state = viewModel.currentState {
            return state.currentItem.formattedBlinds
        } else if let firstItem = viewModel.items.first {
            return firstItem.formattedBlinds
        }
        return ""
    }
}

#Preview("Таймер запущен") {
    let viewModel = PreviewData.timerViewModel(.running(level: 0))
    return TimerLevelCard()
        .padding()
        .environment(viewModel)
}

#Preview("На паузе") {
    let viewModel = PreviewData.timerViewModel(.paused(level: 2))
    return TimerLevelCard()
        .padding()
        .environment(viewModel)
}

#Preview("Перерыв") {
    let viewModel = PreviewData.timerViewModel(.breakTime)
    return TimerLevelCard()
        .padding()
        .environment(viewModel)
}
