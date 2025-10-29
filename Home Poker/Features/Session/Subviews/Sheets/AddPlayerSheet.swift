import SwiftUI
import SwiftData

struct AddPlayerSheet: View {
    let session: Session    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var buyInAmount: Int? = nil
    @State private var settleWithBank = false
    @State private var bankContributionAmount: Int? = nil
    
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

                Section {
                    Toggle("Рассчитаться с банком сейчас", isOn: $settleWithBank)
                        .onChange(of: settleWithBank) { _, newValue in
                            guard newValue else {
                                bankContributionAmount = nil
                                return
                            }
                            guard let amount = buyInAmount, amount > 0 else {
                                settleWithBank = false
                                return
                            }
                            bankContributionAmount = amount
                        }

                    if settleWithBank {
                        TextField("Сумма для банка", value: $bankContributionAmount, format: .number)
                            .keyboardType(.numberPad)
                    }
                } footer: {
                    if settleWithBank {
                        Text("Игрок сразу вносит наличные за закуп.")
                    }
                }
            }
        }
        .onChange(of: buyInAmount) { _, newValue in
            guard settleWithBank else { return }
            guard let amount = newValue, amount > 0 else {
                settleWithBank = false
                bankContributionAmount = nil
                return
            }
            bankContributionAmount = amount
        }
    }
    
    private var canSubmit: Bool {
        guard playerName.nonEmptyTrimmed != nil else { return false }
        guard let amount = buyInAmount, amount > 0 else { return false }
        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return false }
        }
        return true
    }

    private func addPlayer() {
        guard let name = playerName.nonEmptyTrimmed else { return }
        let existingPlayerIDs = Set(session.players.map(\.id))
        guard viewModel.addPlayer(to: session, name: name, buyIn: buyInAmount) else { return }

        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return }
            let newPlayer = session.players.first(where: { !existingPlayerIDs.contains($0.id) })
                ?? session.players.last(where: { $0.name == name })

            if let player = newPlayer {
                guard viewModel.recordBankDeposit(
                    session: session,
                    player: player,
                    amount: bankAmount,
                    note: "Первичный взнос при закупе"
                ) else {
                    return
                }
            }
        }

        dismiss()
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddPlayerSheet(session: session)
        .modelContainer(for: [Session.self, Player.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
        .environment(SessionDetailViewModel())
}
