import Foundation
import SwiftData

@Model
final class PlayerTransaction {
    @Attribute(.unique) var id: UUID = UUID()
    var timestamp: Date
    var type: TransactionType
    var amount: Int
    @Relationship var player: Player?

    init(type: TransactionType, amount: Int, player: Player?, timestamp: Date = Date()) {
        self.type = type
        self.amount = amount
        self.player = player
        self.timestamp = timestamp
    }
}


enum TransactionType: String, Codable, CaseIterable {
    case buyIn
    case addOn
    case cashOut
}
