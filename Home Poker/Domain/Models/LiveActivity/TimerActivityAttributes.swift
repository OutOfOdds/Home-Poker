import Foundation
import ActivityKit

// MARK: - Timer Activity Attributes

/// Атрибуты для Live Activity таймера турнира
struct TimerActivityAttributes: ActivityAttributes {

    // MARK: - Content State

    /// Динамическое состояние Live Activity (обновляется каждую секунду)
    public struct ContentState: Codable, Hashable {
        /// Индекс текущего уровня
        var currentLevelIndex: Int

        /// Small blind текущего уровня
        var smallBlind: Int

        /// Big blind текущего уровня
        var bigBlind: Int

        /// Ante текущего уровня
        var ante: Int

        /// Оставшееся время в текущем уровне (в секундах)
        var remainingSeconds: TimeInterval

        /// Время окончания текущего уровня (для автоматического countdown)
        var levelEndDate: Date

        /// Общее прошедшее время турнира (в секундах)
        var totalElapsedSeconds: TimeInterval

        /// Длительность текущего уровня (для расчета прогресса)
        var levelDurationSeconds: TimeInterval

        /// Таймер запущен
        var isRunning: Bool

        /// Таймер на паузе
        var isPaused: Bool

        /// Это перерыв (break), а не уровень блайндов
        var isBreak: Bool

        /// Название перерыва (если isBreak = true)
        var breakTitle: String?

        // MARK: - Computed Properties

        /// Прогресс текущего уровня (0.0 - 1.0)
        var progress: Double {
            guard levelDurationSeconds > 0 else { return 0 }
            let elapsed = levelDurationSeconds - remainingSeconds
            return min(max(elapsed / levelDurationSeconds, 0), 1)
        }

        /// Форматированное оставшееся время (MM:SS)
        var formattedRemainingTime: String {
            let minutes = Int(remainingSeconds) / 60
            let seconds = Int(remainingSeconds) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        /// Форматированное общее время (HH:MM или MM:SS)
        var formattedTotalElapsed: String {
            let totalMinutes = Int(totalElapsedSeconds) / 60
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if hours > 0 {
                return String(format: "%d:%02d", hours, minutes)
            } else {
                let seconds = Int(totalElapsedSeconds) % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
        }

        /// Текст для отображения уровня
        var levelDisplayText: String {
            if isBreak {
                return breakTitle ?? "Break"
            } else {
                return "SB/BB: \(smallBlind)/\(bigBlind)" + (ante > 0 ? " • Ante: \(ante)" : "")
            }
        }
    }

    // MARK: - Static Attributes

    /// Название турнира (не меняется в течение Live Activity)
    var tournamentName: String

    /// Общее количество уровней в турнире
    var totalLevels: Int
}
