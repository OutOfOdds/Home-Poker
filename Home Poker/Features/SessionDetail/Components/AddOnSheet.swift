import SwiftUI

struct AddOnSheet: View {
    @Bindable var player: Player
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
        guard let amount = Int(buyInAmount), amount > 0 else { return }
        let tx = PlayerTransaction(type: .addOn, amount: amount, player: player)
        player.transactions.append(tx)
        dismiss()
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    return AddOnSheet(player: player)
}
