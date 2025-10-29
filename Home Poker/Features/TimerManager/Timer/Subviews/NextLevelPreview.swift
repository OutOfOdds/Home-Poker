import SwiftUI

/// Превью следующего уровня с навигацией к полному списку
/// - Если state == nil: показывает следующий уровень относительно первого (до запуска)
/// - Если state != nil: показывает следующий уровень относительно текущего
struct NextLevelPreview: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        // Показываем только если есть следующий уровень
        if shouldShow {
            NavigationLink {
                LevelsListView()
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
                        Text(nextItem.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(nextItem.formattedBlinds)
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
        viewModel.currentState?.currentLevelIndex ?? 0
    }

    /// Индекс следующего уровня
    private var nextLevelIndex: Int {
        currentIndex + 1
    }

    /// Следующий уровень (если есть)
    private var nextLevelItem: LevelItem? {
        guard viewModel.items.indices.contains(nextLevelIndex) else { return nil }
        return viewModel.items[nextLevelIndex]
    }

    /// Показывать ли превью (есть ли следующий уровень)
    private var shouldShow: Bool {
        if let state = viewModel.currentState {
            // Если таймер запущен, показываем только если не последний уровень
            return state.currentLevelIndex < viewModel.items.count - 1
        } else {
            // Если таймер не запущен, показываем только если есть хотя бы 2 уровня
            return viewModel.items.count > 1
        }
    }
}

// MARK: - Preview

#Preview("До запуска таймера") {
    let viewModel = PreviewData.timerViewModel(.notStarted)

    NavigationStack {
        Form {
            VStack {
                NextLevelPreview()
            }
        }
    }
    .environment(viewModel)
}

#Preview("Таймер запущен") {
    let viewModel = PreviewData.timerViewModel(.running(level: 1))

    return NavigationStack {
        VStack {
            Spacer()
            NextLevelPreview()
        }
    }
    .environment(viewModel)
}

#Preview("Последний уровень (не показывается)") {
    let viewModel = PreviewData.timerViewModel(.running(level: Int.max))

    return NavigationStack {
        VStack {
            Spacer()
            NextLevelPreview()
        }
    }
    .environment(viewModel)
}
