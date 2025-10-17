import SwiftUI
import SwiftData

struct AddPlayerSheet: View {
    let session: Session
    
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var buyInAmount = ""
    
    var body: some View {
        FormSheetView(
            title: "Добавить игрока",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addPlayer,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Информация об игроке") {
                    TextField("Имя игрока", text: $playerName)
                        .textInputAutocapitalization(.words)

                    TextField("Сумма закупа", text: $buyInAmount)
                        .keyboardType(.numberPad)
                        .onChange(of: buyInAmount) { _, newValue in
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                buyInAmount = digits
                            }
                        }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && (Int(buyInAmount) ?? 0) > 0
    }

    private func addPlayer() {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let buyIn = Int(buyInAmount), buyIn > 0, !trimmedName.isEmpty else { return }
        let player = Player(
            name: trimmedName,
            inGame: true
        )
        session.players.append(player)
        let tx = PlayerTransaction(type: .buyIn, amount: buyIn, player: player)
        player.transactions.append(tx)
        dismiss()
    }
    
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}

#Preview {
    // В превью session не управляемая — это нормально для визуальной проверки UI.
    // В реальном приложении session будет из SwiftData-контейнера.
    let session = Session(
        startTime: Date(),
        location: "Test Location",
        gameType: .NLHoldem, status: .active
    )
    return AddPlayerSheet(session: session)
        .modelContainer(for: [Session.self, Player.self], inMemory: true)
}
