import Foundation
import SwiftData

@Model
final class ClubMemberStats {
    @Attribute(.unique) var memberId: UUID
    var clubId: UUID

    var sessionsCount: Int
    var winSessionsCount: Int
    var addOnSessionsCount: Int

    var totalBuyIn: Int
    var totalCashOut: Int
    var totalPokerPnL: Int
    var totalRealPnL: Int
    var totalRakeback: Int

    var bestSessionRealPnL: Int
    var worstSessionRealPnL: Int
    var updatedAt: Date

    init(memberId: UUID, clubId: UUID) {
        self.memberId = memberId
        self.clubId = clubId
        self.sessionsCount = 0
        self.winSessionsCount = 0
        self.addOnSessionsCount = 0
        self.totalBuyIn = 0
        self.totalCashOut = 0
        self.totalPokerPnL = 0
        self.totalRealPnL = 0
        self.totalRakeback = 0
        self.bestSessionRealPnL = 0
        self.worstSessionRealPnL = 0
        self.updatedAt = Date()
    }
}

extension ClubMemberStats {
    var winRate: Double {
        guard sessionsCount > 0 else { return 0 }
        return Double(winSessionsCount) / Double(sessionsCount)
    }

    var addOnRate: Double {
        guard sessionsCount > 0 else { return 0 }
        return Double(addOnSessionsCount) / Double(sessionsCount)
    }

    var roi: Double {
        guard totalBuyIn > 0 else { return 0 }
        return Double(totalRealPnL) / Double(totalBuyIn)
    }

    var averageRealPnL: Double {
        guard sessionsCount > 0 else { return 0 }
        return Double(totalRealPnL) / Double(sessionsCount)
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
    var pokerPnL: Int
    var realPnL: Int
    var rakeback: Int
    var hasAddOn: Bool

    init(
        sessionId: UUID,
        memberId: UUID,
        clubId: UUID,
        sessionDate: Date,
        sessionTitle: String,
        buyIn: Int,
        cashOut: Int,
        pokerPnL: Int,
        realPnL: Int,
        rakeback: Int,
        hasAddOn: Bool
    ) {
        self.key = Self.makeKey(sessionId: sessionId, memberId: memberId)
        self.sessionId = sessionId
        self.memberId = memberId
        self.clubId = clubId
        self.sessionDate = sessionDate
        self.sessionTitle = sessionTitle
        self.buyIn = buyIn
        self.cashOut = cashOut
        self.pokerPnL = pokerPnL
        self.realPnL = realPnL
        self.rakeback = rakeback
        self.hasAddOn = hasAddOn
    }

    static func makeKey(sessionId: UUID, memberId: UUID) -> String {
        "\(sessionId.uuidString)|\(memberId.uuidString)"
    }
}
