//
//  NextLevelPreview.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

/// Превью следующего уровня с навигацией к полному списку
/// - Если state == nil: показывает следующий уровень относительно первого (до запуска)
/// - Если state != nil: показывает следующий уровень относительно текущего
struct NextLevelPreview: View {
    let state: TimerState?
    let items: [LevelItem]
    let viewModel: TimerViewModel

    var body: some View {
        // Показываем только если есть следующий уровень
        if shouldShow {
            NavigationLink {
                LevelsListView(
                    items: items,
                    currentIndex: currentIndex,
                    viewModel: viewModel
                )
            } label: {
                previewContent
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Subviews

    private var previewContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Следующий уровень")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let nextItem = nextLevelItem {
                    HStack(spacing: 8) {
                        Text(viewModel.levelTitle(for: nextItem))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(viewModel.formatBlinds(for: nextItem))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Индекс текущего уровня
    private var currentIndex: Int {
        state?.currentLevelIndex ?? 0
    }

    /// Индекс следующего уровня
    private var nextLevelIndex: Int {
        currentIndex + 1
    }

    /// Следующий уровень (если есть)
    private var nextLevelItem: LevelItem? {
        guard items.indices.contains(nextLevelIndex) else { return nil }
        return items[nextLevelIndex]
    }

    /// Показывать ли превью (есть ли следующий уровень)
    private var shouldShow: Bool {
        if let state = state {
            // Если таймер запущен, показываем только если не последний уровень
            return state.currentLevelIndex < items.count - 1
        } else {
            // Если таймер не запущен, показываем только если есть хотя бы 2 уровня
            return items.count > 1
        }
    }
}

// MARK: - Preview

#Preview("До запуска таймера") {
    NavigationStack {
        Form {
            VStack {
                NextLevelPreview(
                    state: nil,
                    items: TimerViewModel().items,
                    viewModel: TimerViewModel()
                )
            }
        }
    }
}

#Preview("Таймер запущен") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()

    return NavigationStack {
        VStack {
            Spacer()

            if let state = viewModel.currentState {
                NextLevelPreview(
                    state: state,
                    items: viewModel.items,
                    viewModel: viewModel
                )
            }
        }
    }
}

#Preview("Последний уровень (не показывается)") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()

    // Переключаемся на последний уровень
    for _ in 0..<viewModel.items.count - 1 {
        viewModel.skipToNext()
    }

    return NavigationStack {
        VStack {
            Spacer()

            if let state = viewModel.currentState {
                NextLevelPreview(
                    state: state,
                    items: viewModel.items,
                    viewModel: viewModel
                )
            } else {
                Text("Превью не отображается (последний уровень)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
