import Foundation

// MARK: - Validation Result

enum ValidationResult: Equatable {
    case valid
    case warning(String)
    case error(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .valid: return nil
        case .warning(let msg), .error(let msg): return msg
        }
    }
}

// MARK: - Validation Warnings

enum ValidationWarning: Identifiable, Equatable {
    case bbNotDoubleSB(level: Int, sb: Int, bb: Int)
    case nonIncreasing(level: Int, currentBB: Int, previousBB: Int)
    case stackTooSmall(startingStack: Int, startingBB: Int)
    case stackTooLarge(startingStack: Int, startingBB: Int)

    var id: String {
        message
    }

    var message: String {
        switch self {
        case .bbNotDoubleSB(let level, let sb, let bb):
            return "Уровень \(level): BB (\(bb)) должен быть в 2 раза больше SB (\(sb))"
        case .nonIncreasing(let level, let current, let previous):
            return "Уровень \(level): блайнды не возрастают (BB \(current) <= \(previous))"
        case .stackTooSmall(let stack, let bb):
            return "Стартовый стек \(stack) слишком мал для BB \(bb) (менее 50 BB)"
        case .stackTooLarge(let stack, let bb):
            return "Стартовый стек \(stack) слишком велик для BB \(bb) (более 500 BB)"
        }
    }

    var severity: ValidationSeverity {
        switch self {
        case .bbNotDoubleSB, .nonIncreasing:
            return .error
        case .stackTooSmall, .stackTooLarge:
            return .warning
        }
    }
}

enum ValidationSeverity {
    case warning
    case error
}

// MARK: - Validation Functions

struct BlindValidation {

    /// Проверяет что BB = SB * 2
    static func validateBlinds(sb: Int, bb: Int) -> ValidationResult {
        if bb == sb * 2 {
            return .valid
        }
        return .error("Big Blind должен быть ровно в 2 раза больше Small Blind")
    }

    /// Проверяет структуру блайндов на корректность
    static func validateStructure(levels: [BlindLevel]) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []

        for i in 0..<levels.count {
            let level = levels[i]

            // Проверка BB = SB * 2
            if level.bigBlind != level.smallBlind * 2 {
                warnings.append(.bbNotDoubleSB(level: level.index, sb: level.smallBlind, bb: level.bigBlind))
            }

            // Проверка возрастания (только если не первый уровень)
            if i > 0 {
                let previousLevel = levels[i - 1]
                if level.bigBlind <= previousLevel.bigBlind {
                    warnings.append(.nonIncreasing(
                        level: level.index,
                        currentBB: level.bigBlind,
                        previousBB: previousLevel.bigBlind
                    ))
                }
            }
        }

        return warnings
    }

    /// Проверяет соотношение стека и начальных блайндов
    static func validateStack(startingStack: Int, startingBB: Int) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        let bbDepth = Double(startingStack) / Double(startingBB)

        // Слишком мелкий стек (менее 50 BB)
        if bbDepth < 50 {
            warnings.append(.stackTooSmall(startingStack: startingStack, startingBB: startingBB))
        }

        // Слишком глубокий стек (более 500 BB)
        if bbDepth > 500 {
            warnings.append(.stackTooLarge(startingStack: startingStack, startingBB: startingBB))
        }

        return warnings
    }

    /// Автокоррекция BB на основе SB
    static func correctBB(for sb: Int) -> Int {
        return sb * 2
    }

    /// Автокоррекция SB на основе BB
    static func correctSB(for bb: Int) -> Int {
        return bb / 2
    }
}
