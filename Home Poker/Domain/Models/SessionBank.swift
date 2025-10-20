import Foundation
import SwiftData

@Model
final class SessionBank {
    @Attribute(.unique) var id: UUID = UUID()
    @Relationship(inverse: \Session.bank) var session: Session
    @Relationship var manager: Player?
    var createdAt: Date
    var isClosed: Bool
    var closedAt: Date?
    var expectedTotal: Int
    var totalDeposited: Int
    var totalWithdrawn: Int
    
    var netBalance: Int {
        totalDeposited - totalWithdrawn
    }
    
    var remainingToCollect: Int {
        max(expectedTotal - totalDeposited, 0)
    }

    init(
        session: Session,
        manager: Player? = nil,
        createdAt: Date = Date(),
        isClosed: Bool = false,
        closedAt: Date? = nil,
        expectedTotal: Int = 0,
        totalDeposited: Int = 0,
        totalWithdrawn: Int = 0
    ) {
        self.session = session
        self.manager = manager
        self.createdAt = createdAt
        self.isClosed = isClosed
        self.closedAt = closedAt
        self.expectedTotal = expectedTotal
        self.totalDeposited = totalDeposited
        self.totalWithdrawn = totalWithdrawn
    }
}
