import SwiftUI

struct AddOnSheet: View {
    @Bindable var player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var buyInAmount = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Докупка для \(player.name)") {
                    TextField("Сумма докупки", text: $buyInAmount)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Докупка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        if let amount = Int(buyInAmount), amount > 0 {
                            // Добавляем транзакцию докупки
                            let tx = Transaction(type: .addOn, amount: amount, player: player)
                            // Опционально фиксируем порядок в массиве
                            player.transactions.append(tx)
                            dismiss()
                        }
                    }
                    .disabled(buyInAmount.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = Transaction(type: .buyIn, amount: 2000, player: player)
    return AddOnSheet(player: player)
}
