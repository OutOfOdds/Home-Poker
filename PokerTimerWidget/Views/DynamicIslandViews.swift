import SwiftUI
import ActivityKit

// MARK: - Expanded Views

/// Leading region в expanded Dynamic Island
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Level \(context.state.currentLevelIndex + 1)")
                .font(.caption2)
                .fontWeight(.semibold)

            if !context.state.isBreak {
                Text("\(context.state.smallBlind)/\(context.state.bigBlind)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            } else {
                Text("Break")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }
}

/// Trailing region в expanded Dynamic Island
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if context.state.isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Text(context.state.formattedRemainingTime)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeColor)
        }
    }

    private var timeColor: Color {
        if context.state.isPaused {
            return .orange
        } else if context.state.remainingSeconds < 60 {
            return .red
        } else {
            return .primary
        }
    }
}

/// Bottom region в expanded Dynamic Island
struct ExpandedBottomView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: context.state.progress)
                .tint(progressColor)

            // Blinds info или Break title
            HStack {
                if context.state.isBreak {
                    Text(context.state.breakTitle ?? "Break")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("SB/BB: \(context.state.smallBlind)/\(context.state.bigBlind)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if context.state.ante > 0 {
                        Text("• Ante: \(context.state.ante)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Total elapsed
                Text(context.state.formattedTotalElapsed)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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

// MARK: - Compact Views

/// Leading в compact Dynamic Island (слева от notch)
struct CompactLeadingView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
                .font(.system(size: 12))
                .foregroundStyle(context.state.isPaused ? .orange : .green)

            Text("L\(context.state.currentLevelIndex + 1)")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
    }
}

/// Trailing в compact Dynamic Island (справа от notch)
struct CompactTrailingView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        Text(compactTime)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(timeColor)
    }

    private var compactTime: String {
        let minutes = Int(context.state.remainingSeconds) / 60
        let seconds = Int(context.state.remainingSeconds) % 60

        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    private var timeColor: Color {
        if context.state.isPaused {
            return .orange
        } else if context.state.remainingSeconds < 60 {
            return .red
        } else {
            return .primary
        }
    }
}

// MARK: - Minimal View

/// Minimal Dynamic Island (самый компактный режим)
struct MinimalView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
            .foregroundStyle(context.state.isPaused ? .orange : .green)
    }
}
