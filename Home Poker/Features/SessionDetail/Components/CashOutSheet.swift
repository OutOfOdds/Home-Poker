import SwiftUI

struct CashOutSheet: View {
    @Bindable var player: Player
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
        guard let amount = Int(cashOutAmount) else { return false }
        return amount >= 0
    }

    private func cashOut() {
        guard let amount = Int(cashOutAmount), amount >= 0 else { return }
        let tx = PlayerTransaction(type: .cashOut, amount: amount, player: player)
        player.transactions.append(tx)
        player.inGame = false
        dismiss()
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    return CashOutSheet(player: player)
}
