import SwiftUI
import SwiftData

struct AddPlayerView: View {
    let session: Session
    
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var buyInAmount = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Информация об игроке") {
                    TextField("Имя игрока", text: $playerName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Сумма закупа", text: $buyInAmount)
                        .keyboardType(.numberPad)
                        .onChange(of: buyInAmount) { _, newValue in
                            // Фильтруем ввод до цифр, чтобы избежать невалидного Int
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                buyInAmount = digits
                            }
                        }
                }
            }
            .navigationTitle("Добавить игрока")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let buyIn = Int(buyInAmount), buyIn > 0, !trimmedName.isEmpty {
                            let player = Player(
                                name: trimmedName,
                                isActive: true,
                                buyIn: buyIn
                            )
                            session.players.append(player)
                            dismiss()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && (Int(buyInAmount) ?? 0) > 0
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
    return AddPlayerView(session: session)
        .modelContainer(for: [Session.self, Player.self], inMemory: true)
}
