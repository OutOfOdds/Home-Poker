import SwiftUI
import SwiftData

struct SessionBankTransactionSheet: View {
    @Bindable var session: Session
    let mode: Mode
    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlayerID: UUID?
    @State private var amountText: String = ""
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
        guard let id = selectedPlayerID, players.contains(where: { $0.id == id }) else { return false }
        return Int(amountText).map { $0 > 0 } ?? false
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
                    
                    TextField("Сумма", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, newValue in
                            guard !isUpdatingAmount else { return }
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                amountText = digits
                            } else {
                                amountManuallyEdited = true
                            }
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
        guard
            isFormValid,
            let player = players.first(where: { $0.id == selectedPlayerID })
        else { return }
        
        let didSucceed: Bool
        switch mode {
        case .deposit:
            didSucceed = viewModel.recordBankDeposit(
                session: session,
                player: player,
                amountText: amountText,
                note: note
            )
        case .withdrawal:
            didSucceed = viewModel.recordBankWithdrawal(
                session: session,
                player: player,
                amountText: amountText,
                note: note
            )
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
                updateSuggestedAmountIfNeeded(force: false)
            }
        )
    }
    
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
    
    private var footerContent: some View {
        Group {
            if let bank, let player = selectedPlayer {
                VStack(alignment: .leading, spacing: 4) {
                    let contributions = bank.contributions(for: player)
                    let deposited = contributions.deposited
                    let withdrawn = contributions.withdrawn
                    Text("Игрок внёс: ₽\(deposited)")
                    Text("Игроку выдано: ₽\(withdrawn)")
                    
                    switch mode {
                    case .deposit:
                        Text("Осталось внести: ₽\(bank.outstandingAmount(for: player))")
                            .foregroundStyle(.secondary)
                    case .withdrawal:
                        let available = max(deposited - withdrawn, 0)
                        Text("Доступно к выдаче: ₽\(available)")
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    Text("Всего ожидается: ₽\(bank.expectedTotal)")
                    Text("Получено: ₽\(bank.totalDeposited)")
                    Text("Осталось собрать: ₽\(bank.remainingToCollect)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let bank {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Всего ожидается: ₽\(bank.expectedTotal)")
                    Text("Получено: ₽\(bank.totalDeposited)")
                    Text("Осталось собрать: ₽\(bank.remainingToCollect)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private func updateSuggestedAmountIfNeeded(force: Bool) {
        guard mode == .deposit, let bank, let player = selectedPlayer else { return }
        let outstanding = bank.outstandingAmount(for: player)
        if force || (!amountManuallyEdited && amountText.isEmpty) {
            isUpdatingAmount = true
            amountText = outstanding > 0 ? String(outstanding) : ""
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
    let session = Session(
        startTime: Date(),
        location: "Preview Spot",
        gameType: .NLHoldem,
        status: .active
    )
    let p1 = Player(name: "Илья", inGame: false)
    let p2 = Player(name: "Андрей", inGame: false)
    session.players = [p1, p2]
    session.bank = SessionBank(session: session, manager: p1, expectedTotal: 6000)
    
    return SessionBankTransactionSheet(session: session, mode: .deposit)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
