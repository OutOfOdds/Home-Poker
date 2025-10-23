import SwiftUI

struct PlayerAddOnSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var buyInAmount: Int? = nil
    
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
                    TextField("Сумма докупки", value: $buyInAmount, format: .number)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard let amount = buyInAmount, amount > 0 else { return false }
        return true
    }

    private func addOn() {
        if viewModel.addOn(for: player, in: session, amount: buyInAmount) {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()
    let player = session.players.first(where: { $0.inGame }) ?? PreviewData.activePlayer()

    return PlayerAddOnSheet(player: player, session: session)
        .environment(SessionDetailViewModel())
}
