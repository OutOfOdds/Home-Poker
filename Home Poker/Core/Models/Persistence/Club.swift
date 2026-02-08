import Foundation
import SwiftData

@Model
final class Club {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var sessions: [Session] = []

    @Relationship(deleteRule: .cascade)
    var members: [ClubMember] = []

    init(name: String, createdAt: Date = Date()) {
        self.name = name.trimmed
        self.createdAt = createdAt
    }
}
