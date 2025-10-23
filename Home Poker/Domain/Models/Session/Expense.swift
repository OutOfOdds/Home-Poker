import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID = UUID()
    var amount: Int
    var note: String
    var createdAt: Date
    
    // Плательщик расхода (один)
    @Relationship(deleteRule: .nullify) var payer: Player?
    
    init(amount: Int, note: String, createdAt: Date = Date(), payer: Player? = nil) {
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
        self.payer = payer
    }
}

