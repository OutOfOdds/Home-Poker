import Foundation
import SwiftData
import Observation

@Observable
final class SessionListViewModel {
    @ObservationIgnored
    private(set) var context: ModelContext?

    func deleteSessions(at offsets: IndexSet, from sessions: [Session]) {
        guard let context else { return }
        offsets
            .map { sessions[$0] }
            .forEach { context.delete($0) }
    }

    func delete(_ session: Session) {
        context?.delete(session)
    }
}

