import Foundation

// MARK: - Blind Level

public struct BlindLevel: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var index: Int
    public var smallBlind: Int
    public var bigBlind: Int
    public var ante: Int
    public var minutes: Int

    public init(
        id: UUID = UUID(),
        index: Int,
        smallBlind: Int,
        bigBlind: Int,
        ante: Int,
        minutes: Int
    ) {
        self.id = id
        self.index = index
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.ante = ante
        self.minutes = minutes
    }
}

// MARK: - Level Item

public enum LevelItem: Hashable, Sendable, Codable {
    case blinds(BlindLevel)
    case `break`(BreakInfo)

    // Codable реализация для enum с associated values
    private enum CodingKeys: String, CodingKey {
        case type
        case blinds
        case breakInfo
    }

    private enum ItemType: String, Codable {
        case blinds
        case breakItem
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)

        switch type {
        case .blinds:
            let level = try container.decode(BlindLevel.self, forKey: .blinds)
            self = .blinds(level)
        case .breakItem:
            let info = try container.decode(BreakInfo.self, forKey: .breakInfo)
            self = .break(info)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .blinds(let level):
            try container.encode(ItemType.blinds, forKey: .type)
            try container.encode(level, forKey: .blinds)
        case .break(let info):
            try container.encode(ItemType.breakItem, forKey: .type)
            try container.encode(info, forKey: .breakInfo)
        }
    }
}

// MARK: - Break Info

public struct BreakInfo: Hashable, Codable, Sendable {
    public var title: String = "Break"
    public var minutes: Int

    public init(title: String = "Break", minutes: Int) {
        self.title = title
        self.minutes = minutes
    }
}
