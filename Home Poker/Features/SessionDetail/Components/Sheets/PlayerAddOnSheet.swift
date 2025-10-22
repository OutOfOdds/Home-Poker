import SwiftUI

struct PlayerAddOnSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var buyInAmount = ""
    
    var body: some View {
        FormSheetView(
            title: "Докупка",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addOn,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Докупка для \(player.name)") {
                    TextField("Сумма докупки", text: $buyInAmount.digitsOnly())
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var canSubmit: Bool {
        return buyInAmount.positiveInt != nil
    }

    private func addOn() {
        guard viewModel.addOn(for: player, in: session, amountText: buyInAmount) else { return }
        dismiss()
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    let session = Session(
        startTime: Date(),
        location: "Preview",
        gameType: .NLHoldem,
        status: .active
    )
    session.players.append(player)
    return PlayerAddOnSheet(player: player, session: session)
        .environment(SessionDetailViewModel())
}
