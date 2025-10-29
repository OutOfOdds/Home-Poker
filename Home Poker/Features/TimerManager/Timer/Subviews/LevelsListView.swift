import SwiftUI

/// Список всех уровней блайндов с возможностью редактирования
struct LevelsListView: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        List {
            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                LevelRow(
                    item: item,
                    index: index,
                    isCurrent: index == currentIndex,
                    isPast: index < currentIndex
                )
            }
        }
        .navigationTitle("Структура блайндов")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentIndex: Int {
        viewModel.currentState?.currentLevelIndex ?? 0
    }
}

// MARK: - Level Row

struct LevelRow: View {
    @Environment(TimerViewModel.self) private var viewModel

    let item: LevelItem
    let index: Int
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        HStack {
            // Индикатор текущего уровня
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(isCurrent ? .primary : .secondary)

                Text(item.formattedBlinds)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(item.durationMinutes) мин")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Кнопка редактирования удалена (неиспользуемый код)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isRunning {
                withAnimation {
                    viewModel.jumpToLevel(at: index)
                }
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
    let viewModel = PreviewData.timerViewModel(.notStarted)

    NavigationStack {
        LevelsListView()
    }
    .environment(viewModel)
}

#Preview("Таймер на 3-м уровне") {
    let viewModel = PreviewData.timerViewModel(.running(level: 2))

    NavigationStack {
        LevelsListView()
    }
    .environment(viewModel)
}

#Preview("Отдельная строка уровня") {
    let viewModel = PreviewData.timerViewModel(.running(level: 0))

    List {
        if let firstItem = viewModel.items.first {
            LevelRow(
                item: firstItem,
                index: 0,
                isCurrent: true,
                isPast: false
            )
        }
    }
    .environment(viewModel)
}
