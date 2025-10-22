import SwiftUI
import SwiftData

struct PlayerCashOutSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cashOutAmount: Int? = nil

    var body: some View {
        FormSheetView(
            title: "Завершить игру",
            confirmTitle: "Завершить",
            isConfirmDisabled: !canSubmit,
            confirmAction: cashOut,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    TextField("Сумма на вывод", value: $cashOutAmount, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Завершение игры для \(player.name)")
                }
                footer: {
                    Text("")
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        guard let amount = cashOutAmount else { return false }
        return amount >= 0
    }

    private func cashOut() {
        if viewModel.cashOut(session: session, player: player, amount: cashOutAmount) {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.sessionWithBank()
    let player = session.players.first(where: { $0.inGame }) ?? PreviewData.activePlayer()

    PlayerCashOutSheet(player: player, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel(service: SessionService()))
}
