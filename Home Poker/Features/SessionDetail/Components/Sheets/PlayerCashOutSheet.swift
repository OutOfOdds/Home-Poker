import SwiftUI
import SwiftData

struct PlayerCashOutSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cashOutAmount = ""
    @State private var recordDeposit = false
    @State private var depositAmount = ""

    var body: some View {
        FormSheetView(
            title: "Завершить игру",
            confirmTitle: "Завершить",
            isConfirmDisabled: !canSubmit,
            confirmAction: cashOut,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Завершение игры для \(player.name)") {
                    TextField("Сумма на вывод", text: $cashOutAmount)
                        .keyboardType(.numberPad)
                        .onChange(of: cashOutAmount) { _, newValue in
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                cashOutAmount = digits
                            }
                        }
                    }
                }
                
                Section("Сессионный банк") {
                    Toggle("Отметить возврат денег", isOn: $recordDeposit)
                        .disabled(isBankClosed)
                        .onChange(of: recordDeposit) { _, isOn in
                            if isOn {
                                let bank = viewModel.ensureBank(for: session)
                                if bank.isClosed {
                                    viewModel.alertMessage = SessionServiceError.bankClosed.errorDescription
                                    recordDeposit = false
                                    return
                                }
                                depositAmount = ""
                            } else {
                                depositAmount = ""
                            }
                        }
                    
                    if recordDeposit {
                        TextField("Сумма взноса", text: $depositAmount)
                            .keyboardType(.numberPad)
                            .onChange(of: depositAmount) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue {
                                    depositAmount = digits
                                }
                            }
                    }
                }
            }
        }
    
    private var canSubmit: Bool {
        viewModel.isValidCashOutInput(cashOutAmount) &&
        (!recordDeposit || ((Int(depositAmount) ?? 0) > 0))
    }

    private func cashOut() {
        guard viewModel.cashOut(session: session, player: player, amountText: cashOutAmount) else {
            return
        }
        
        if recordDeposit {
            let note = "Взнос при завершении игры"
            guard viewModel.recordBankDeposit(
                session: session,
                player: player,
                amountText: depositAmount,
                note: note
            ) else {
                return
            }
        }
        
        dismiss()
    }
    
    private var isBankClosed: Bool {
        session.bank?.isClosed ?? false
    }
    
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    let session = Session(
        startTime: Date(),
        location: "Preview Club",
        gameType: .NLHoldem,
        status: .active
    )
    session.bank = SessionBank(session: session, expectedTotal: 2000)
    session.players.append(player)
    return PlayerCashOutSheet(player: player, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
