import Foundation
import SwiftData

struct NewSessionInput {
    var startTime: Date
    var title: String
    var location: String
    var gameType: GameType
    var smallBlind: Int?
    var bigBlind: Int?
    var ante: Int?
}

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
            status: .active,
            sessionTitle: input.title.trimmed
        )

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
