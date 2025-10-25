//
//  LevelsListView.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

/// Список всех уровней блайндов с возможностью редактирования
struct LevelsListView: View {
    let items: [LevelItem]
    let currentIndex: Int
    let viewModel: TimerViewModel

    @State private var isEditingLevel = false
    @State private var editingLevel: BlindLevel?
    @State private var editingLevelIndex: Int?

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                LevelRow(
                    item: item,
                    index: index,
                    isCurrent: index == currentIndex,
                    isPast: index < currentIndex,
                    viewModel: viewModel,
                    onEdit: {
                        if case .blinds(let level) = item {
                            editingLevel = level
                            editingLevelIndex = index
                            isEditingLevel = true
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle("Структура блайндов")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingLevel) {
            if let level = editingLevel, let index = editingLevelIndex {
                EditLevelSheet(levelIndex: index, currentLevel: level, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Level Row

struct LevelRow: View {
    let item: LevelItem
    let index: Int
    let isCurrent: Bool
    let isPast: Bool
    let viewModel: TimerViewModel
    let onEdit: () -> Void

    var body: some View {
        HStack {
            // Индикатор текущего уровня
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.levelTitle(for: item))
                    .font(.headline)
                    .foregroundStyle(isCurrent ? .primary : .secondary)

                Text(viewModel.formatBlinds(for: item))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(viewModel.levelDuration(for: item)) мин")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Кнопка редактирования (только для блайндов, не для перерывов)
            if case .blinds = item {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isRunning {
                viewModel.jumpToLevel(at: index)
            }
        }
    }

    // MARK: - Computed Properties

    private var indicatorColor: Color {
        if isCurrent {
            return .blue
        } else if isPast {
            return .green.opacity(0.3)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview("Список уровней") {
    NavigationStack {
        LevelsListView(
            items: TimerViewModel().items,
            currentIndex: 0,
            viewModel: TimerViewModel()
        )
    }
}

#Preview("Таймер на 3-м уровне") {
    let viewModel = TimerViewModel()
    viewModel.startTimer()
    viewModel.skipToNext()
    viewModel.skipToNext()

    return NavigationStack {
        LevelsListView(
            items: viewModel.items,
            currentIndex: viewModel.currentState?.currentLevelIndex ?? 0,
            viewModel: viewModel
        )
    }
}

#Preview("Отдельная строка уровня") {
    let viewModel = TimerViewModel()
    if let firstItem = viewModel.items.first {
        List {
            LevelRow(
                item: firstItem,
                index: 0,
                isCurrent: true,
                isPast: false,
                viewModel: viewModel,
                onEdit: { print("Edit") }
            )
        }
    }
}
