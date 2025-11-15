import Foundation

public struct BlindLevel: Identifiable, Hashable, Codable {
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

public enum LevelItem: Hashable {
    case blinds(BlindLevel)
    case `break`(BreakInfo)
}

// MARK: - Break Info

public struct BreakInfo: Hashable, Codable {
    public var title: String = "Break"
    public var minutes: Int

    public init(title: String = "Break", minutes: Int) {
        self.title = title
        self.minutes = minutes
    }
}
