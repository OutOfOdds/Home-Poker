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
                Section("Завершение игры для \(player.name)") {
                    TextField("Сумма на вывод", value: $cashOutAmount, format: .number)
                        .keyboardType(.numberPad)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        viewModel.isValidCashOutAmount(cashOutAmount)
    }

    private func cashOut() {
        if viewModel.cashOut(session: session, player: player, amount: cashOutAmount) {
            dismiss()
        }
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    let session = Session(
        startTime: Date(),
        location: "Preview Club",
        gameType: .NLHoldem,
        status: .active
    )
    session.bank = SessionBank(session: session, expectedTotal: 2000)
    session.players.append(player)
    return PlayerCashOutSheet(player: player, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel(service: SessionService()))
}
