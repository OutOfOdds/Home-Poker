import Foundation
import SwiftData

@Model
final class SessionBankEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date
    var amount: Int
    var type: SessionBankEntryType
    var note: String
    @Relationship var player: Player
    @Relationship(inverse: \SessionBank.entries) var bank: SessionBank
    
    init(
        amount: Int,
        type: SessionBankEntryType,
        player: Player,
        bank: SessionBank,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.amount = amount
        self.type = type
        self.player = player
        self.bank = bank
        self.note = note
        self.createdAt = createdAt
    }
}

enum SessionBankEntryType: String, Codable, CaseIterable {
    case deposit
    case withdrawal
}
