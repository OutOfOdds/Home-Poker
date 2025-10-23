import SwiftUI
import SwiftData

struct PlayerCashOutSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var chipsCashoutAmount: Int? = nil
    @State private var moneyToSessionBank: Int? = nil
    @State private var instantSettlement: Bool = false

    /// Сколько игрок должен внести в банк после учёта введённого cash-out.
    private var projectedDebt: Int {
        let totalCashedOut = player.cashOut + max(chipsCashoutAmount ?? 0, 0)
        return max(player.buyIn - totalCashedOut, 0)
    }
    
    var body: some View {
        FormSheetView(
            title: "Завершить игру",
            confirmTitle: "Завершить",
            isConfirmDisabled: !canSubmit,
            confirmAction: cashOut,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    TextField("Сколько фишек вывести", value: $chipsCashoutAmount, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Вывод фишек игрока \(player.name)")
                }
                
                Toggle("Рассчитаться с банком сейчас", isOn: $instantSettlement)
                    .onChange(of: instantSettlement) { _, newValue in
                        guard newValue else {
                            moneyToSessionBank = nil
                            return
                        }
                        let debt = projectedDebt
                        if debt > 0 {
                            moneyToSessionBank = debt
                        } else {
                            instantSettlement = false
                        }
                    }
                
                if instantSettlement {
                    Section {
                        TextField("Сумма для банка", value: $moneyToSessionBank, format: .number)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Игрок готов пополнить банк на:")
                    }
                    footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Игрок вносит деньги в банк за выведенные фишки.")
                            Text("Осталось внести: \(projectedDebt.asCurrency())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onChange(of: chipsCashoutAmount) { _, _ in
                guard instantSettlement else { return }
                let debt = projectedDebt
                if debt > 0 {
                    moneyToSessionBank = debt
                } else {
                    instantSettlement = false
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        guard let amount = chipsCashoutAmount else { return false }
        guard amount >= 0 else { return false }
        if instantSettlement {
            guard let bankAmount = moneyToSessionBank, bankAmount > 0 else { return false }
        }
        return true
    }

    private func cashOut() {
        guard viewModel.cashOut(session: session, player: player, amount: chipsCashoutAmount) else { return }

        if instantSettlement {
            guard viewModel.recordBankDeposit(session: session, player: player, amount: moneyToSessionBank, note: "Расчёт при выходе") else {
                return
            }
        }

        dismiss()
    }
}

#Preview {
    let session = PreviewData.sessionWithBank()
    let player = session.players.first(where: { $0.inGame }) ?? PreviewData.activePlayer()

    PlayerCashOutSheet(player: player, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel(service: SessionService()))
}
