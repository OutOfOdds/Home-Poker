import SwiftUI
import SwiftData

struct SessionBankTransactionSheet: View {
    @Bindable var session: Session
    let mode: Mode
    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlayerID: UUID?
    @State private var amount: Int? = nil
    @State private var note: String = ""
    @State private var amountManuallyEdited = false
    @State private var isUpdatingAmount = false
    
    private var players: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var selectedPlayer: Player? {
        guard let id = selectedPlayerID else { return nil }
        return players.first(where: { $0.id == id })
    }
    
    private var bank: SessionBank? {
        session.bank
    }
    
    private var isFormValid: Bool {
        guard selectedPlayer != nil else { return false }
        guard let amount, amount > 0 else { return false }
        return true
    }
    
    var body: some View {
        FormSheetView(
            title: mode.title,
            confirmTitle: mode.confirmTitle,
            isConfirmDisabled: !isFormValid,
            confirmAction: submit,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    Picker("Игрок", selection: playerBinding) {
                        ForEach(players, id: \.id) { player in
                            Text(player.name).tag(Optional(player.id))
                        }
                    }
                    
                    TextField("Сумма", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .onChange(of: amount) { _, _ in
                            guard !isUpdatingAmount else { return }
                            amountManuallyEdited = true
                        }
                    
                    TextField("Заметка (опционально)", text: $note, axis: .vertical)
                } footer: {
                    footerContent
                }
            }
        }
        .onAppear {
            viewModel.ensureBank(for: session)
            if selectedPlayerID == nil {
                selectedPlayerID = mode == .deposit
                ? session.bank?.manager?.id ?? players.first?.id
                : players.first?.id
            }
            updateSuggestedAmountIfNeeded(force: true)
        }
    }
    
    private func submit() {
        guard isFormValid, let player = selectedPlayer else { return }
        
        let didSucceed: Bool
        switch mode {
        case .deposit:
            didSucceed = viewModel.recordBankDeposit(session: session, player: player, amount: amount, note: note)
        case .withdrawal:
            didSucceed = viewModel.recordBankWithdrawal(session: session, player: player, amount: amount, note: note)
        }
        
        if didSucceed {
            dismiss()
        }
    }
    
    private var playerBinding: Binding<UUID?> {
        Binding(
            get: { selectedPlayerID },
            set: {
                selectedPlayerID = $0
                amountManuallyEdited = false // Сбрасываем флаг при смене игрока
                updateSuggestedAmountIfNeeded(force: false)
            }
        )
    }

    private var footerContent: some View {
        Group {
            if let bank, let player = selectedPlayer {
                VStack(alignment: .leading, spacing: 4) {
                    let contributions = bank.contributions(for: player)
                    let deposited = contributions.deposited
                    let withdrawn = contributions.withdrawn
                    Text("Игрок внёс: \(deposited.asCurrency())")
                    Text("Игроку выдано: \(withdrawn.asCurrency())")
                    
                    switch mode {
                    case .deposit:
                        let bankOwes = bank.amountOwedByBank(for: player)
                        let playerOwes = bank.amountOwedToBank(for: player)

                        if bankOwes > 0 {
                            if player.profit > 0 {
                                Text("Игрок выиграл: \(bankOwes.asCurrency())")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Переплата: \(bankOwes.asCurrency())")
                                    .foregroundStyle(.blue)
                            }
                        } else if playerOwes > 0 {
                            Text("Осталось внести: \(playerOwes.asCurrency())")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Расчёты закрыты")
                                .foregroundStyle(.secondary)
                        }
                    case .withdrawal:
                        let available = max(deposited - withdrawn, 0)
                        Text("Доступно к выдаче: \(available.asCurrency())")
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    Text("Получено: \(bank.totalDeposited.asCurrency())")
                    Text("Осталось собрать: \(bank.remainingToCollect.asCurrency())")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let bank {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Получено: \(bank.totalDeposited.asCurrency())")
                    Text("Осталось собрать: \(bank.remainingToCollect.asCurrency())")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private func updateSuggestedAmountIfNeeded(force: Bool) {
        guard mode == .deposit, let bank, let player = selectedPlayer else { return }
        let playerOwes = bank.amountOwedToBank(for: player)
        // Обновляем сумму если:
        // - force = true (при первом открытии)
        // - пользователь не редактировал сумму вручную после смены игрока
        if force || !amountManuallyEdited {
            isUpdatingAmount = true
            amount = playerOwes > 0 ? playerOwes : nil
            DispatchQueue.main.async {
                self.isUpdatingAmount = false
            }
        }
        if force {
            amountManuallyEdited = false
        }
    }
}

enum Mode {
    case deposit
    case withdrawal
    
    var title: String {
        switch self {
        case .deposit:
            return "Принять взнос"
        case .withdrawal:
            return "Выдать деньги"
        }
    }
    
    var confirmTitle: String {
        switch self {
        case .deposit:
            return "Принять"
        case .withdrawal:
            return "Выдать"
        }
    }
}

#Preview {
    let session = PreviewData.sessionWithBank()

    return SessionBankTransactionSheet(session: session, mode: .deposit)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
