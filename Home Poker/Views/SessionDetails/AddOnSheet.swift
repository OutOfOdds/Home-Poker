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
                            player.buyIn += amount
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
    AddOnSheet(player: Player(name: "Илья", isActive: true, buyIn: 2000))
}
