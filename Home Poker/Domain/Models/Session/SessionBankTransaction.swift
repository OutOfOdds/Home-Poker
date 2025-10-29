import Foundation
import SwiftData

@Model
final class SessionBankTransaction {
    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date
    var amount: Int
    var type: SessionBankTransactionType
    var note: String


    @Relationship(inverse: \Player.sessionBankTransactions) var player: Player?
    @Relationship(inverse: \SessionBank.transactions) var bank: SessionBank
    
    init(
        amount: Int,
        type: SessionBankTransactionType,
        player: Player?,
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

enum SessionBankTransactionType: String, Codable, CaseIterable {
    case deposit
    case withdrawal
}
