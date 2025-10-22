import SwiftUI
import SwiftData

struct AddPlayerSheet: View {
    let session: Session    
    @Environment(SessionDetailViewModel.self) private var viewModel
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

                    TextField("Сумма закупа", text: $buyInAmount.digitsOnly())
                        .keyboardType(.numberPad)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        guard playerName.nonEmptyTrimmed != nil else { return false }
        return buyInAmount.positiveInt != nil
    }

    private func addPlayer() {
        guard let name = playerName.nonEmptyTrimmed else { return }
        guard viewModel.addPlayer(to: session, name: name, buyInText: buyInAmount) else { return }
        dismiss()
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
        .modelContainer(for: [Session.self, Player.self, SessionBank.self, SessionBankEntry.self], inMemory: true)
        .environment(SessionDetailViewModel())
}
