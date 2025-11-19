import Foundation
import SwiftData

protocol SessionsRepository {
    func fetchSessions() throws -> [Session]
    @discardableResult
    func createSession(from input: NewSessionInput) throws -> Session
    func deleteSessions(_ sessions: [Session]) throws
}

final class SwiftDataSessionsRepository: SessionsRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchSessions() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func createSession(from input: NewSessionInput) throws -> Session {
        let session = Session(
            startTime: input.startTime,
            location: input.location.trimmed,
            gameType: input.gameType,
            sessionType: input.sessionType,
            status: .active,
            sessionTitle: input.title.trimmed
        )

        // Кеш-игра поля
        if input.sessionType == .cash {
            if let ratio = input.cashToChipsRatio, ratio > 0 {
                session.chipsToCashRatio = ratio
            }
        }

        // Турнир поля
        if input.sessionType == .tournament {
            session.entryFee = input.entryFee
            session.startingStack = input.startingStack
            session.allowReEntry = input.allowReEntry ?? false
        }

        // Блайнды (общие)
        if let sb = input.smallBlind, sb > 0 {
            session.smallBlind = sb
        }
        if let bb = input.bigBlind, bb > 0 {
            session.bigBlind = bb
        }
        if let ante = input.ante, ante >= 0 {
            session.ante = ante
        }

        context.insert(session)
        try context.save()
        return session
    }

    func deleteSessions(_ sessions: [Session]) throws {
        sessions.forEach(context.delete)
        try context.save()
    }
}

struct NewSessionInput {
    var startTime: Date
    var title: String
    var location: String
    var gameType: GameType
    var sessionType: SessionType

    // Кеш-игра поля
    var cashToChipsRatio: Int?

    // Турнир поля
    var entryFee: Int?
    var startingStack: Int?
    var allowReEntry: Bool?

    var smallBlind: Int?
    var bigBlind: Int?
    var ante: Int?
}
