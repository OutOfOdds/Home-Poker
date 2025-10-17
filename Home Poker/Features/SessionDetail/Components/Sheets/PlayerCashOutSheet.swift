import SwiftUI

struct PlayerCashOutSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cashOutAmount = ""

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
                    TextField("Сумма на вывод", text: $cashOutAmount)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var canSubmit: Bool {
        viewModel.isValidCashOutInput(cashOutAmount)
    }

    private func cashOut() {
        if viewModel.cashOut(session: session, player: player, amountText: cashOutAmount) {
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
    session.players.append(player)
    return PlayerCashOutSheet(player: player, session: session)
        .environment(SessionDetailViewModel())
}
