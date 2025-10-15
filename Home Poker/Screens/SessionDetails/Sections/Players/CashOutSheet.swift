import SwiftUI

struct CashOutSheet: View {
    @Bindable var player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var cashOutAmount = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Завершение игры для \(player.name)") {
                    TextField("Сумма на вывод", text: $cashOutAmount)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Завершить игру")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Завершить") {
                        if let amount = Int(cashOutAmount), amount >= 0 {
                            // Фиксируем кэш-аут транзакцией и деактивируем игрока
                            let tx = Transaction(type: .cashOut, amount: amount, player: player)
                            player.transactions.append(tx)
                            player.inGame = false
                            dismiss()
                        }
                    }
                    .disabled(cashOutAmount.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = Transaction(type: .buyIn, amount: 2000, player: player)
    return CashOutSheet(player: player)
}
