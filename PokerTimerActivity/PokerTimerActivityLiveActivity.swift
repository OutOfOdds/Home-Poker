//
//  PokerTimerActivityLiveActivity.swift
//  PokerTimerActivity
//
//  Created by Odds on 21.11.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PokerTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Current level info
        var currentLevelIndex: Int
        var currentLevelTitle: String          // "Уровень 3" or "Break"
        var currentSmallBlind: Int?            // nil for breaks
        var currentBigBlind: Int?
        var currentAnte: Int?

        // Timing
        var remainingSeconds: Int              // For countdown display
        var levelEndDate: Date                 // For live countdown updates

        // Next level
        var nextLevelTitle: String?
        var nextLevelBlinds: String?           // "200/400" or "Break • 15 мин"

        // State
        var isPaused: Bool
        var totalLevels: Int

        // Progress
        var progressFraction: Double           // currentLevel / totalLevels
    }

    // Fixed non-changing properties
    var tournamentName: String
    var startTime: Date
}

struct PokerTimerActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PokerTimerActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - показывается при долгом нажатии на Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                // Compact leading - левая часть свернутого Dynamic Island
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                // Compact trailing - правая часть свернутого Dynamic Island
                CompactTrailingView(state: context.state)
            } minimal: {
                // Minimal - самое компактное представление
                MinimalView(state: context.state)
            }
            .keylineTint(Color.orange)
            .contentMargins(.all, 25, for: .expanded)

        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let attributes: PokerTimerActivityAttributes
    let state: PokerTimerActivityAttributes.ContentState

    private var isBreak: Bool {
        state.currentSmallBlind == nil && state.currentBigBlind == nil
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // Left: Timer
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.levelEndDate, style: .timer)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(state.remainingSeconds < 60 ? .red : .white)

                    HStack(spacing: 4) {
                        if state.isPaused {
                            Image(systemName: "pause.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text("Уровень \(state.currentLevelIndex + 1)/\(state.totalLevels)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right: Blinds info
                VStack(alignment: .trailing, spacing: 2) {
                    if isBreak {
                        HStack(spacing: 4) {
                            Text("Перерыв")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title3)
                                .foregroundStyle(.purple)
                        }
                    } else if let sb = state.currentSmallBlind,
                              let bb = state.currentBigBlind {
                        HStack(spacing: 3) {
                            Text("\(sb)/\(bb)")
                                .font(.title2)
                                .fontWeight(.bold)
                            if let ante = state.currentAnte, ante > 0 {
                                Text("(\(ante))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Next level
                    if let nextBlinds = state.nextLevelBlinds {
                        Text("Далее: \(nextBlinds)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Progress bar
            ProgressView(value: state.progressFraction)
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Dynamic Island - Expanded Views

private struct ExpandedLeadingView: View {
    let state: PokerTimerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.currentLevelTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExpandedCenterView: View {
    let state: PokerTimerActivityAttributes.ContentState

    var body: some View {
        // Центральная иконка или визуальный индикатор
        if let sb = state.currentSmallBlind,
           let bb = state.currentBigBlind {
            HStack(spacing: 2) {
                Text("\(sb)/\(bb)")
                if let ante = state.currentAnte, ante > 0 {
                    Text(" \(ante)")
                }
            }
            .font(.subheadline)
        } else {
            Text("Перерыв")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

private struct ExpandedTrailingView: View {
    let state: PokerTimerActivityAttributes.ContentState

    var body: some View {
        Text(state.levelEndDate, style: .timer)
            .font(.title)
            .fontWeight(.bold)
            .monospacedDigit()
            .foregroundStyle(state.remainingSeconds < 60 ? .red : .white)
            .multilineTextAlignment(.trailing)
    }
}

private struct ExpandedBottomView: View {
    let attributes: PokerTimerActivityAttributes
    let state: PokerTimerActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            // Progress indicator
            HStack(spacing: 8) {
                Text(attributes.tournamentName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Text("Уровень \(state.currentLevelIndex + 1)/\(state.totalLevels)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: state.progressFraction)
                .tint(.orange)

            // Next level info
            if let nextTitle = state.nextLevelTitle,
               let nextBlinds = state.nextLevelBlinds {
                HStack {
                    Spacer()
                    Text("Далее:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(nextTitle)
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(nextBlinds)
                        .font(.caption2)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Dynamic Island - Compact Views

private struct CompactLeadingView: View {
    let state: PokerTimerActivityAttributes.ContentState

    private var levelNumber: Int {
        state.currentLevelIndex + 1
    }

    private var isBreak: Bool {
        state.currentSmallBlind == nil && state.currentBigBlind == nil
    }

    private var levelIcon: String {
        if state.isPaused {
            return "pause.circle.fill"
        } else if isBreak {
            return "cup.and.saucer.fill"
        } else if levelNumber <= 50 {
            return "\(levelNumber).circle.fill"
        } else {
            return "circle.fill"
        }
    }

    private var iconColor: Color {
        if state.isPaused {
            return .orange
        } else if isBreak {
            return .purple
        } else {
            return .green
        }
    }

    var body: some View {
        Image(systemName: levelIcon)
            .foregroundStyle(iconColor)
    }
}

private struct CompactTrailingView: View {
    let state: PokerTimerActivityAttributes.ContentState

    var body: some View {
        Text(state.levelEndDate, style: .timer)
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(state.remainingSeconds < 60 ? .red : .white)
            .frame(width: 30)
    }
}

// MARK: - Dynamic Island - Minimal View

private struct MinimalView: View {
    let state: PokerTimerActivityAttributes.ContentState

    private var levelNumber: Int {
        state.currentLevelIndex + 1
    }

    private var isBreak: Bool {
        state.currentSmallBlind == nil && state.currentBigBlind == nil
    }

    private var levelIcon: String {
        if state.isPaused {
            return "pause.circle.fill"
        } else if isBreak {
            return "cup.and.saucer.fill"
        } else if levelNumber <= 50 {
            return "\(levelNumber).circle.fill"
        } else {
            return "circle.fill"
        }
    }

    private var iconColor: Color {
        if state.isPaused {
            return .orange
        } else if isBreak {
            return .purple
        } else {
            return .green
        }
    }

    var body: some View {
        Image(systemName: levelIcon)
            .foregroundStyle(iconColor)
    }
}

// MARK: - Preview Data

extension PokerTimerActivityAttributes {
    fileprivate static var preview: PokerTimerActivityAttributes {
        PokerTimerActivityAttributes(
            tournamentName: "Вечерний турнир",
            startTime: Date()
        )
    }

    fileprivate static var previewLong: PokerTimerActivityAttributes {
        PokerTimerActivityAttributes(
            tournamentName: "Большой покерный турнир с длинным названием",
            startTime: Date()
        )
    }
}

extension PokerTimerActivityAttributes.ContentState {
    /// Обычный уровень с блайндами
    fileprivate static var normalLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 2,
            currentLevelTitle: "Уровень 3",
            currentSmallBlind: 200,
            currentBigBlind: 400,
            currentAnte: 50,
            remainingSeconds: 450, // 7:30
            levelEndDate: Date().addingTimeInterval(450),
            nextLevelTitle: "Уровень 4",
            nextLevelBlinds: "300/600 (75)",
            isPaused: false,
            totalLevels: 12,
            progressFraction: 0.25
        )
    }

    /// Break
    fileprivate static var breakLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 5,
            currentLevelTitle: "Break",
            currentSmallBlind: nil,
            currentBigBlind: nil,
            currentAnte: nil,
            remainingSeconds: 600, // 10:00
            levelEndDate: Date().addingTimeInterval(600),
            nextLevelTitle: "Уровень 7",
            nextLevelBlinds: "500/1000 (100)",
            isPaused: false,
            totalLevels: 12,
            progressFraction: 0.5
        )
    }

    /// Уровень на паузе
    fileprivate static var pausedLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 7,
            currentLevelTitle: "Уровень 8",
            currentSmallBlind: 800,
            currentBigBlind: 1600,
            currentAnte: 200,
            remainingSeconds: 320, // 5:20
            levelEndDate: Date().addingTimeInterval(320),
            nextLevelTitle: "Уровень 9",
            nextLevelBlinds: "1000/2000 (300)",
            isPaused: true,
            totalLevels: 12,
            progressFraction: 0.67
        )
    }

    /// Последняя минута (urgency)
    fileprivate static var urgentLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 9,
            currentLevelTitle: "Уровень 10",
            currentSmallBlind: 1500,
            currentBigBlind: 3000,
            currentAnte: 500,
            remainingSeconds: 45, // 0:45
            levelEndDate: Date().addingTimeInterval(45),
            nextLevelTitle: "Уровень 11",
            nextLevelBlinds: "2000/4000 (600)",
            isPaused: false,
            totalLevels: 12,
            progressFraction: 0.83
        )
    }

    /// Последний уровень (без следующего)
    fileprivate static var lastLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 11,
            currentLevelTitle: "Уровень 12",
            currentSmallBlind: 3000,
            currentBigBlind: 6000,
            currentAnte: 1000,
            remainingSeconds: 180, // 3:00
            levelEndDate: Date().addingTimeInterval(180),
            nextLevelTitle: nil,
            nextLevelBlinds: nil,
            isPaused: false,
            totalLevels: 12,
            progressFraction: 1.0
        )
    }

    /// Первый уровень без ante
    fileprivate static var firstLevel: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(
            currentLevelIndex: 0,
            currentLevelTitle: "Уровень 1",
            currentSmallBlind: 50,
            currentBigBlind: 100,
            currentAnte: 0,
            remainingSeconds: 540, // 9:00
            levelEndDate: Date().addingTimeInterval(540),
            nextLevelTitle: "Уровень 2",
            nextLevelBlinds: "75/150",
            isPaused: false,
            totalLevels: 12,
            progressFraction: 0.08
        )
    }
}

// MARK: - Previews

// Dynamic Island Previews (с живым таймером)
#Preview("DI: Обычный уровень", as: .dynamicIsland(.compact), using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.normalLevel
}

#Preview("DI: Break", as: .dynamicIsland(.compact), using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.breakLevel
}

#Preview("DI: На паузе", as: .dynamicIsland(.compact), using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.pausedLevel
}

#Preview("DI: Expanded", as: .dynamicIsland(.expanded), using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.normalLevel
}

#Preview("DI: Minimal", as: .dynamicIsland(.minimal), using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.urgentLevel
}

// Lock Screen Previews
#Preview("Lock: Обычный уровень", as: .content, using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.normalLevel
}

#Preview("Lock: Break", as: .content, using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.breakLevel
}

#Preview("Lock: Последняя минута", as: .content, using: PokerTimerActivityAttributes.preview) {
    PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.urgentLevel
}
