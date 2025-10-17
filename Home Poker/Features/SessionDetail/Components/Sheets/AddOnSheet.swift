import SwiftUI

struct AddOnSheet: View {
    @Bindable var player: Player
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
                    TextField("Сумма докупки", text: $buyInAmount)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard let amount = Int(buyInAmount) else { return false }
        return amount > 0
    }

    private func addOn() {
        guard viewModel.addOn(for: player, amountText: buyInAmount) else { return }
        dismiss()
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    return AddOnSheet(player: player)
        .environment(SessionDetailViewModel())
}
