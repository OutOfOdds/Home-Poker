import Foundation
import SwiftData

struct ClubMemberStatsService {
    func refreshStats(for session: Session) {
        guard session.sessionType == .cash else { return }
        guard let club = session.club else { return }
        guard let context = session.modelContext else { return }

        let oldRows = fetchRows(forSessionID: session.id, context: context)
        var oldRowsByKey = Dictionary(uniqueKeysWithValues: oldRows.map { ($0.key, $0) })

        let computedRows = computeRows(for: session, in: club)
        let newRowKeys = Set(computedRows.keys)
        let oldRowKeys = Set(oldRowsByKey.keys)
        let affectedMemberIDs = Set(oldRows.map(\.memberId))
            .union(computedRows.keys.compactMap { key in
                computedRows[key]?.memberId
            })

        // Update existing rows and create new ones
        for row in computedRows.values {
            if let existing = oldRowsByKey[row.key] {
                existing.sessionDate = row.sessionDate
                existing.sessionTitle = row.sessionTitle
                existing.buyIn = row.buyIn
                existing.cashOut = row.cashOut
                existing.pokerPnL = row.pokerPnL
                existing.realPnL = row.realPnL
                existing.rakeback = row.rakeback
                existing.hasAddOn = row.hasAddOn
            } else {
                context.insert(
                    ClubMemberSessionStats(
                        sessionId: session.id,
                        memberId: row.memberId,
                        clubId: club.id,
                        sessionDate: row.sessionDate,
                        sessionTitle: row.sessionTitle,
                        buyIn: row.buyIn,
                        cashOut: row.cashOut,
                        pokerPnL: row.pokerPnL,
                        realPnL: row.realPnL,
                        rakeback: row.rakeback,
                        hasAddOn: row.hasAddOn
                    )
                )
            }
        }

        // Delete stale rows
        let staleKeys = oldRowKeys.subtracting(newRowKeys)
        for staleKey in staleKeys {
            if let staleRow = oldRowsByKey[staleKey] {
                context.delete(staleRow)
                oldRowsByKey.removeValue(forKey: staleKey)
            }
        }

        for memberID in affectedMemberIDs {
            recalculateAggregate(for: memberID, clubID: club.id, context: context)
        }
    }

    func removeStats(forDeletedSession session: Session, context: ModelContext) {
        let rows = fetchRows(forSessionID: session.id, context: context)
        guard !rows.isEmpty else { return }

        let memberIDs = Set(rows.map(\.memberId))
        let clubID = session.club?.id ?? rows.first?.clubId

        rows.forEach(context.delete)

        if let clubID {
            for memberID in memberIDs {
                recalculateAggregate(for: memberID, clubID: clubID, context: context)
            }
        }
    }

    func removeStats(for member: ClubMember, context: ModelContext) {
        let memberID = member.id

        let sessionDescriptor = FetchDescriptor<ClubMemberSessionStats>(
            predicate: #Predicate { $0.memberId == memberID }
        )
        let aggregateDescriptor = FetchDescriptor<ClubMemberStats>(
            predicate: #Predicate { $0.memberId == memberID }
        )

        if let rows = try? context.fetch(sessionDescriptor) {
            rows.forEach(context.delete)
        }

        if let aggregates = try? context.fetch(aggregateDescriptor) {
            aggregates.forEach(context.delete)
        }
    }

    func removeStats(for club: Club, context: ModelContext) {
        let clubID = club.id

        let sessionDescriptor = FetchDescriptor<ClubMemberSessionStats>(
            predicate: #Predicate { $0.clubId == clubID }
        )
        let aggregateDescriptor = FetchDescriptor<ClubMemberStats>(
            predicate: #Predicate { $0.clubId == clubID }
        )

        if let rows = try? context.fetch(sessionDescriptor) {
            rows.forEach(context.delete)
        }

        if let aggregates = try? context.fetch(aggregateDescriptor) {
            aggregates.forEach(context.delete)
        }
    }
}

private extension ClubMemberStatsService {
    struct ComputedSessionRow {
        let key: String
        let memberId: UUID
        let sessionDate: Date
        let sessionTitle: String
        let buyIn: Int
        let cashOut: Int
        let pokerPnL: Int
        let realPnL: Int
        let rakeback: Int
        let hasAddOn: Bool
    }

    struct RowAccumulator {
        var buyIn: Int = 0
        var cashOut: Int = 0
        var pokerPnL: Int = 0
        var realPnL: Int = 0
        var rakeback: Int = 0
        var hasAddOn: Bool = false
    }

    func fetchRows(forSessionID sessionID: UUID, context: ModelContext) -> [ClubMemberSessionStats] {
        let descriptor = FetchDescriptor<ClubMemberSessionStats>(
            predicate: #Predicate { $0.sessionId == sessionID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchRows(forMemberID memberID: UUID, clubID: UUID, context: ModelContext) -> [ClubMemberSessionStats] {
        let descriptor = FetchDescriptor<ClubMemberSessionStats>(
            predicate: #Predicate { $0.memberId == memberID && $0.clubId == clubID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchAggregate(forMemberID memberID: UUID, context: ModelContext) -> ClubMemberStats? {
        let descriptor = FetchDescriptor<ClubMemberStats>(
            predicate: #Predicate { $0.memberId == memberID }
        )
        return try? context.fetch(descriptor).first
    }

    func computeRows(for session: Session, in club: Club) -> [String: ComputedSessionRow] {
        let ratio = max(session.chipsToCashRatio, 1)
        let expensePaidByPlayer = buildExpensePaidMap(for: session)
        let expenseShareByPlayer = buildExpenseShareMap(for: session)
        let bankNetByPlayer = buildBankNetMap(for: session)

        var accumulators: [UUID: RowAccumulator] = [:]

        for player in session.players {
            guard let memberID = resolveMemberID(for: player, in: club) else { continue }

            let buyIn = player.chipBuyIn * ratio
            let cashOut = player.chipCashOut * ratio
            let pokerPnL = (player.chipCashOut - player.chipBuyIn) * ratio
            let rakeback = player.getsRakeback ? player.rakeback : 0
            let expensePaid = expensePaidByPlayer[player.id] ?? 0
            let expenseShare = expenseShareByPlayer[player.id] ?? 0
            let bankNet = bankNetByPlayer[player.id] ?? 0
            let realPnL = pokerPnL + rakeback + bankNet + expensePaid - expenseShare
            let hasAddOn = player.transactions.contains(where: { $0.type == .chipAddOn })

            var accumulator = accumulators[memberID] ?? RowAccumulator()
            accumulator.buyIn += buyIn
            accumulator.cashOut += cashOut
            accumulator.pokerPnL += pokerPnL
            accumulator.realPnL += realPnL
            accumulator.rakeback += rakeback
            accumulator.hasAddOn = accumulator.hasAddOn || hasAddOn
            accumulators[memberID] = accumulator
        }

        var rows: [String: ComputedSessionRow] = [:]
        for (memberID, accumulator) in accumulators {
            let key = ClubMemberSessionStats.makeKey(sessionId: session.id, memberId: memberID)
            rows[key] = ComputedSessionRow(
                key: key,
                memberId: memberID,
                sessionDate: session.startTime,
                sessionTitle: session.displayTitle,
                buyIn: accumulator.buyIn,
                cashOut: accumulator.cashOut,
                pokerPnL: accumulator.pokerPnL,
                realPnL: accumulator.realPnL,
                rakeback: accumulator.rakeback,
                hasAddOn: accumulator.hasAddOn
            )
        }
        return rows
    }

    func resolveMemberID(for player: Player, in club: Club) -> UUID? {
        if let clubMemberID = player.clubMemberID {
            if club.members.contains(where: { $0.id == clubMemberID }) {
                return clubMemberID
            }
            player.clubMemberID = nil
        }

        if let matchedMember = club.members.first(where: {
            $0.name.lowercased() == player.name.lowercased()
        }) {
            player.clubMemberID = matchedMember.id
            return matchedMember.id
        }

        return nil
    }

    func buildExpensePaidMap(for session: Session) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        for expense in session.expenses {
            if let payerID = expense.payer?.id {
                map[payerID, default: 0] += expense.amount
            }
        }
        return map
    }

    func buildExpenseShareMap(for session: Session) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        for expense in session.expenses {
            for distribution in expense.distributions {
                map[distribution.player.id, default: 0] += distribution.amount
            }
        }
        return map
    }

    func buildBankNetMap(for session: Session) -> [UUID: Int] {
        guard let bank = session.bank else { return [:] }

        var map: [UUID: Int] = [:]
        for transaction in bank.transactions {
            guard let playerID = transaction.player?.id else { continue }
            switch transaction.type {
            case .deposit:
                map[playerID, default: 0] += transaction.amount
            case .withdrawal, .expensePayment, .tipPayment:
                map[playerID, default: 0] -= transaction.amount
            }
        }
        return map
    }

    func recalculateAggregate(for memberID: UUID, clubID: UUID, context: ModelContext) {
        let rows = fetchRows(forMemberID: memberID, clubID: clubID, context: context)
        let existingAggregate = fetchAggregate(forMemberID: memberID, context: context)

        guard !rows.isEmpty else {
            if let existingAggregate {
                context.delete(existingAggregate)
            }
            return
        }

        let aggregate = existingAggregate ?? ClubMemberStats(memberId: memberID, clubId: clubID)
        if existingAggregate == nil {
            context.insert(aggregate)
        }

        aggregate.clubId = clubID
        aggregate.sessionsCount = rows.count
        aggregate.winSessionsCount = rows.filter { $0.realPnL > 0 }.count
        aggregate.addOnSessionsCount = rows.filter { $0.hasAddOn }.count
        aggregate.totalBuyIn = rows.reduce(0) { $0 + $1.buyIn }
        aggregate.totalCashOut = rows.reduce(0) { $0 + $1.cashOut }
        aggregate.totalPokerPnL = rows.reduce(0) { $0 + $1.pokerPnL }
        aggregate.totalRealPnL = rows.reduce(0) { $0 + $1.realPnL }
        aggregate.totalRakeback = rows.reduce(0) { $0 + $1.rakeback }
        aggregate.bestSessionRealPnL = rows.map(\.realPnL).max() ?? 0
        aggregate.worstSessionRealPnL = rows.map(\.realPnL).min() ?? 0
        aggregate.updatedAt = Date()
    }
}
