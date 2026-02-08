import Foundation
import SwiftData

@Model
final class ClubMember {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var createdAt: Date

    @Relationship(inverse: \Club.members)
    var club: Club

    init(name: String, club: Club, createdAt: Date = Date()) {
        self.name = name.trimmed
        self.club = club
        self.createdAt = createdAt
    }
}

