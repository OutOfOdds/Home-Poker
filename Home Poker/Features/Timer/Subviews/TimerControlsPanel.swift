//
//  TimerControlsPanel.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

/// Панель управления таймером
struct TimerControlsPanel: View {
    let viewModel: TimerViewModel
    @Binding var showResetAlert: Bool
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            // Кнопка "Назад"
            Button {
                viewModel.skipToPrevious()
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
                viewModel.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .tint(.indigo)
            .disabled(!viewModel.isRunning)
            .buttonStyle(.bordered)
            
            Spacer()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var playPauseButton: some View {
        if viewModel.canStart {
            // Кнопка "Старт"
            Button {
                viewModel.startTimer()
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
                viewModel.togglePause()
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
                viewModel.togglePause()
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
            showResetAlert = true
        } label: {
            Image(systemName: "xmark")
                .font(.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.orange)
    }
}

// MARK: - Preview

#Preview("Начальное состояние (canStart)") {
    @Previewable @State var showAlert = false
    let viewModel = TimerViewModel()

    return VStack {
        TimerControlsPanel(viewModel: viewModel, showResetAlert: $showAlert)
    }
}
