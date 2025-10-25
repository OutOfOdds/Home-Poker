//
//  TimerView.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

struct TimerView: View {
    @State private var viewModel = TimerViewModel()
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            if viewModel.showConfigForm {
                // Форма настройки турнира
                TournamentConfigView(
                    config: $viewModel.tournamentConfig,
                    onStart: {
                        withAnimation {
                            viewModel.startTournament()
                        }
                    }
                )
            } else {
                // Таймер
                Form {
                    TimerLevelCard(state: viewModel.currentState, viewModel: viewModel)
                        .listRowSeparator(.hidden)

                    // Превью следующего уровня
                    Section {
                        NextLevelPreview(
                            state: viewModel.currentState,
                            items: viewModel.items,
                            viewModel: viewModel
                        )
                    }
                    Section {
                        // Панель управления
                        TimerControlsPanel(
                            viewModel: viewModel,
                            showResetAlert: $showResetAlert
                        )
                    }
                }
                .navigationTitle("Таймер")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showResetAlert = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
        }
        .alert("Сбросить турнир?", isPresented: $showResetAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Сбросить", role: .destructive) {
                withAnimation {
                    viewModel.resetToConfig()
                }
            }
        } message: {
            Text("Турнир будет остановлен, и вы вернётесь к настройке.")
        }
    }
}

// MARK: - Preview

#Preview("Таймер") {
    TabView {
        Tab("Таймер", systemImage: "timer") {
            TimerView()
        }
    }
}
