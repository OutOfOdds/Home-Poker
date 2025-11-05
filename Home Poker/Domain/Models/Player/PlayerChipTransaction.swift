import Foundation
import SwiftData

@Model
final class PlayerChipTransaction {
    @Attribute(.unique) var id: UUID = UUID()
    var timestamp: Date
    var type: TransactionType
    var chipAmount: Int
    @Relationship var player: Player?

    init(type: TransactionType, amount: Int, player: Player?, timestamp: Date = Date()) {
        self.type = type
        self.chipAmount = amount
        self.player = player
        self.timestamp = timestamp
    }
}


enum TransactionType: String, Codable, CaseIterable {
    case chipBuyIn
    case chipAddOn
    case ChipCashOut
}
