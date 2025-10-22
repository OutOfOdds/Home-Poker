import SwiftUI
import SwiftData

struct AddPlayerSheet: View {
    let session: Session    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var buyInAmount: Int? = nil
    
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

                    TextField("Сумма закупа", value: $buyInAmount, format: .number)
                        .keyboardType(.numberPad)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        guard playerName.nonEmptyTrimmed != nil else { return false }
        guard let amount = buyInAmount, amount > 0 else { return false }
        return true
    }

    private func addPlayer() {
        guard let name = playerName.nonEmptyTrimmed else { return }
        if viewModel.addPlayer(to: session, name: name, buyIn: buyInAmount) {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddPlayerSheet(session: session)
        .modelContainer(for: [Session.self, Player.self, SessionBank.self, SessionBankEntry.self], inMemory: true)
        .environment(SessionDetailViewModel())
}
