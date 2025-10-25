//
//  TimerLevelCard.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

/// Карточка текущего уровня таймера
/// - Если state == nil: показывает начальное состояние (до запуска)
/// - Если state != nil: показывает текущее состояние с таймером
struct TimerLevelCard: View {
    let state: TimerState?
    let viewModel: TimerViewModel
    
    var body: some View {
            // Большой таймер - главный фокус
            HStack {
                timerDisplay
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if case .blinds = state?.currentItem {
                HStack {
                    VStack(spacing: 8) {
                        // Название уровня
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

                        timerStatusIndicator(isPaused: state?.isPaused ?? true)
                            .frame(maxWidth: .infinity, alignment: .center)

                        
                    }
                }
            } else if case .break = state?.currentItem {
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
    // MARK: - Subviews
    
    @ViewBuilder
    private var timerDisplay: some View {
        if let state = state {
            // Таймер запущен - показываем оставшееся время
            Text(viewModel.formatTime(state.remainingTimeInLevel))
                .font(.system(size: 96, weight: .bold, design: .monospaced))
                .foregroundStyle(state.isPaused ? .secondary : .primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        } else if let firstItem = viewModel.items.first {
            // Таймер не запущен - показываем длительность первого уровня
            let minutes = viewModel.levelDuration(for: firstItem)
            Text(viewModel.formatTime(TimeInterval(minutes * 60)))
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
    
    // MARK: - Computed Properties
    
    private var levelTitle: String {
        if let state = state {
            return viewModel.levelTitle(for: state.currentItem)
        } else if let firstItem = viewModel.items.first {
            return viewModel.levelTitle(for: firstItem)
        }
        return ""
    }
    
    private var blindsText: String {
        if let state = state {
            return viewModel.formatBlinds(for: state.currentItem)
        } else if let firstItem = viewModel.items.first {
            return viewModel.formatBlinds(for: firstItem)
        }
        return ""
    }
}

// MARK: - Preview

#Preview("Таймер запущен") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()
    
    return TimerLevelCard(state: viewModel.currentState, viewModel: viewModel)
        .padding()
}

#Preview("На паузе") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()
    viewModel.togglePause()
    
    return TimerLevelCard(state: viewModel.currentState, viewModel: viewModel)
        .padding()
}

#Preview("Перерыв") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()
    
    // Пропустить 4 уровня, чтобы попасть на перерыв
    viewModel.skipToNext()  // → Уровень 2
    viewModel.skipToNext()  // → Уровень 3
    viewModel.skipToNext()  // → Уровень 4
    viewModel.skipToNext()  // → Перерыв
    
    return TimerLevelCard(state: viewModel.currentState, viewModel: viewModel)
        .padding()
}
