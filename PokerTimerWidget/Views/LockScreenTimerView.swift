import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Lock Screen Timer View

struct LockScreenTimerView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header: Tournament name + Level
            HStack {
                Text(context.attributes.tournamentName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("Level \(context.state.currentLevelIndex + 1)/\(context.attributes.totalLevels)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Main content
            HStack(alignment: .center, spacing: 16) {
                // Left: Blinds info
                VStack(alignment: .leading, spacing: 4) {
                    if context.state.isBreak {
                        Text(context.state.breakTitle ?? "Break")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("SB/BB")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(context.state.smallBlind)/\(context.state.bigBlind)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        if context.state.ante > 0 {
                            Text("Ante: \(context.state.ante)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Right: Timer
                VStack(alignment: .trailing, spacing: 4) {
                    if context.state.isPaused {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Пауза")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(context.state.formattedRemainingTime)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timeColor)

                    Text("осталось")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            ProgressView(value: context.state.progress)
                .tint(progressColor)
                .background(.quaternary)

            // Footer: Total elapsed time
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Всего: \(context.state.formattedTotalElapsed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .activityBackgroundTint(.clear)
    }

    // MARK: - Computed Properties

    private var timeColor: Color {
        if context.state.isPaused {
            return .orange
        } else if context.state.remainingSeconds < 60 {
            return .red
        } else if context.state.remainingSeconds < 180 {
            return .orange
        } else {
            return .primary
        }
    }

    private var progressColor: Color {
        if context.state.isBreak {
            return .cyan
        } else if context.state.progress > 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}
