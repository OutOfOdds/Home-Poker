import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID = UUID()
    var amount: Int
    var note: String
    var createdAt: Date
    
    init(amount: Int, note: String, createdAt: Date = Date(), session: Session? = nil) {
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
    }
}
