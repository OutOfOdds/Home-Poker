import SwiftUI
import Observation
import SwiftData

@Observable
final class SessionDetailViewModel {
    @ObservationIgnored
    private let sessionService: SessionService

    var alertMessage: String?

    init(session: Session, service: SessionService) {
        self.sessionService = service
    }

    func cashOut(session: Session, player: Player, amount: Int) -> Bool {
        do {
            try sessionService.cashOut(player: player, amount: amount, in: session)
            return true
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось выполнить вывод."
            return false
        }
    }

    func clearAlert() {
        alertMessage = nil
    }
}
