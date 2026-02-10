import Foundation
import SwiftData

@Model
final class ClubMemberStats {
    @Attribute(.unique) var memberId: UUID
    var clubId: UUID

    var sessionsCount: Int
    var winSessionsCount: Int

    var totalBuyIn: Int
    var totalCashOut: Int
    var totalRealPnL: Int
    var totalRakeback: Int

    var updatedAt: Date

    init(memberId: UUID, clubId: UUID) {
        self.memberId = memberId
        self.clubId = clubId
        self.sessionsCount = 0
        self.winSessionsCount = 0
        self.totalBuyIn = 0
        self.totalCashOut = 0
        self.totalRealPnL = 0
        self.totalRakeback = 0
        self.updatedAt = Date()
    }
}

extension ClubMemberStats {
    var winRate: Double {
        guard sessionsCount > 0 else { return 0 }
        return Double(winSessionsCount) / Double(sessionsCount)
    }

    var roi: Double {
        guard totalBuyIn > 0 else { return 0 }
        return Double(totalRealPnL) / Double(totalBuyIn)
    }
}

@Model
final class ClubMemberSessionStats {
    @Attribute(.unique) var key: String
    var sessionId: UUID
    var memberId: UUID
    var clubId: UUID
    var sessionDate: Date
    var sessionTitle: String

    var buyIn: Int
    var cashOut: Int
    var realPnL: Int
    var rakeback: Int

    init(
        sessionId: UUID,
        memberId: UUID,
        clubId: UUID,
        sessionDate: Date,
        sessionTitle: String,
        buyIn: Int,
        cashOut: Int,
        realPnL: Int,
        rakeback: Int
    ) {
        self.key = Self.makeKey(sessionId: sessionId, memberId: memberId)
        self.sessionId = sessionId
        self.memberId = memberId
        self.clubId = clubId
        self.sessionDate = sessionDate
        self.sessionTitle = sessionTitle
        self.buyIn = buyIn
        self.cashOut = cashOut
        self.realPnL = realPnL
        self.rakeback = rakeback
    }

    static func makeKey(sessionId: UUID, memberId: UUID) -> String {
        "\(sessionId.uuidString)|\(memberId.uuidString)"
    }
}
