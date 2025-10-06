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
                            player.cashOut = amount
                            player.isActive = false
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
    CashOutSheet(player: Player(name: "Илья", isActive: true, buyIn: 2000))
}
