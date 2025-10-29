import Foundation

// MARK: - BlindLevel Formatting Extensions

extension BlindLevel {
    /// Форматирует блайнды для отображения (например: "100/200" или "100/200 (25)")
    var formattedBlinds: String {
        if ante > 0 {
            return "\(smallBlind)/\(bigBlind) (\(ante))"
        } else {
            return "\(smallBlind)/\(bigBlind)"
        }
    }
}

// MARK: - LevelItem Formatting Extensions

extension LevelItem {
    /// Форматирует блайнды для отображения
    var formattedBlinds: String {
        switch self {
        case .blinds(let level):
            return level.formattedBlinds
        case .break(let breakInfo):
            return breakInfo.title
        }
    }

    /// Возвращает название уровня
    var title: String {
        switch self {
        case .blinds(let level):
            return "Уровень \(level.index)"
        case .break(let breakInfo):
            return breakInfo.title
        }
    }

    /// Возвращает длительность в минутах
    var durationMinutes: Int {
        switch self {
        case .blinds(let level):
            return level.minutes
        case .break(let breakInfo):
            return breakInfo.minutes
        }
    }
}

// MARK: - TimeInterval Formatting Extensions

extension TimeInterval {
    /// Форматирует TimeInterval в строку вида "12:45" или "1:05:30"
    var formattedTime: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
