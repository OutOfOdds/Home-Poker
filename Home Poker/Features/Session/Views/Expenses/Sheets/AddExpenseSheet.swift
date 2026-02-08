import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let session: Session

    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expenseDescription = ""
    @State private var expenseAmount: Int? = nil
    @State private var payerSelection: ExpenseSource = .later
    @State private var selectedPayerId: UUID?
    @State private var organizerDistributionMode: OrganizerDistributionMode = .none
    @State private var organizerSelectedPlayerIds: Set<UUID> = []

    var body: some View {
        FormSheetView(
            title: "Добавить расход",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addExpense,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    TextField("Описание расхода", text: $expenseDescription)
                        .textInputAutocapitalization(.sentences)

                    GroupedIntegerTextField(
                        placeholder: "Сумма",
                        value: $expenseAmount
                    )

                } header: {
                    Text("Информация о расходе")
                        .font(.caption)
                } footer: {
                    Text("Важно: добавляйте только общие расходы, которые влияют на выплаты между игроками. Личные траты (например, еда для конкретного игрока) не нужно записывать.")
                        .font(.caption)
                }

                Section {
                    Picker("Источник оплаты", selection: $payerSelection) {
                        Text("Указать позже").tag(ExpenseSource.later)
                        Text("Игрок").tag(ExpenseSource.player)
                        if canSelectBank {
                            Text("Касса").tag(ExpenseSource.bank)
                        }
                        if canSelectRake {
                            Text("Рейк").tag(ExpenseSource.rake)
                        }
                        Text("Оплачено организаторами").tag(ExpenseSource.organizers)
                    }
                    
                    if payerSelection == .player {
                        Picker("Оплатил игрок", selection: $selectedPayerId) {
                            ForEach(session.players, id: \.id) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                    } else if payerSelection == .bank {
                        HStack {
                            Text("Доступно в кассе")
                            Spacer()
                            Text(bankBalance.asCurrency())
                                .fontWeight(.semibold)
                        }
                    } else if payerSelection == .rake {
                        HStack {
                            Text("Доступно рейка")
                            Spacer()
                            Text(availableRake.asCurrency())
                                .fontWeight(.semibold)
                        }
                    } else if payerSelection == .organizers {
                        Picker("Списать с игроков", selection: $organizerDistributionMode) {
                            Text("Без вычета").tag(OrganizerDistributionMode.none)
                            Text("Поровну на всех").tag(OrganizerDistributionMode.allPlayers)
                            Text("Только выбранные").tag(OrganizerDistributionMode.selectedPlayers)
                        }

                        if organizerDistributionMode == .selectedPlayers {
                            ForEach(session.players, id: \.id) { player in
                                Toggle(isOn: organizerSelectionBinding(for: player.id)) {
                                    HStack {
                                        Text(player.name)
                                        Spacer()
                                        if let amount = organizerDistributionByPlayerId[player.id] {
                                            Text("-\(amount.asCurrency())")
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                }
                                .toggleStyle(CheckboxToggleStyle())
                            }
                        }

                        if organizerDistributionMode != .selectedPlayers,
                           let amount = expenseAmount,
                           amount > 0,
                           !organizerTargetPlayers.isEmpty {
                            ForEach(organizerDistributions(for: amount), id: \.player.id) { distribution in
                                HStack {
                                    Text(distribution.player.name)
                                    Spacer()
                                    Text("-\(distribution.amount.asCurrency())")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Источник оплаты")
                        .font(.caption)
                } footer: {
                    sourceFooter
                }
            }
        }
        .onAppear {
            if selectedPayerId == nil {
                selectedPayerId = session.players.first?.id
            }
            if organizerSelectedPlayerIds.isEmpty {
                organizerSelectedPlayerIds = Set(session.players.map(\.id))
            }
        }
        .onChange(of: payerSelection) { _, newValue in
            if newValue == .player, selectedPayerId == nil {
                selectedPayerId = session.players.first?.id
            }

            if newValue == .organizers, organizerSelectedPlayerIds.isEmpty {
                organizerSelectedPlayerIds = Set(session.players.map(\.id))
            }
        }
        .onChange(of: organizerDistributionMode) { _, newValue in
            if newValue == .selectedPlayers, organizerSelectedPlayerIds.isEmpty {
                organizerSelectedPlayerIds = Set(session.players.map(\.id))
            }
        }
    }

    private var canSubmit: Bool {
        guard expenseDescription.nonEmptyTrimmed != nil else { return false }
        guard let amount = expenseAmount, amount > 0 else { return false }
        switch payerSelection {
        case .later:
            return true
        case .player:
            return selectedPayerId != nil
        case .bank:
            return amount <= bankBalance
        case .rake:
            return amount <= availableRake
        case .organizers:
            switch organizerDistributionMode {
            case .none:
                return true
            case .allPlayers:
                return !session.players.isEmpty
            case .selectedPlayers:
                return !organizerTargetPlayers.isEmpty
            }
        }
    }

    private func addExpense() {
        guard let note = expenseDescription.nonEmptyTrimmed else { return }
        let payer = selectedPayer
        guard let expense = viewModel.addExpense(
            to: session,
            note: note,
            amount: expenseAmount,
            payer: payer,
            source: payerSelection
        ) else {
            return
        }

        switch payerSelection {
        case .later:
            break
        case .player:
            break
        case .bank:
            if !viewModel.payExpenseFromBank(expense: expense, amount: expenseAmount, from: session) {
                viewModel.removeExpenses([expense], from: session)
                return
            }
        case .rake:
            expense.paidFromRake = expense.amount
        case .organizers:
            let distributions = organizerDistributions(for: expense.amount)
                .map { ($0.player, $0.amount) }
            if !distributions.isEmpty &&
                !viewModel.saveExpenseDistribution(
                    for: expense,
                    distributions: distributions,
                    rakeAmount: 0,
                    in: session
                ) {
                viewModel.removeExpenses([expense], from: session)
                return
            }
        }
        dismiss()
    }

    private var selectedPayer: Player? {
        guard payerSelection == .player, let id = selectedPayerId else { return nil }
        return session.players.first { $0.id == id }
    }

    private var bankBalance: Int {
        session.bank?.netBalance ?? 0
    }

    private var availableRake: Int {
        viewModel.availableRakeForExpenses(for: session)
    }

    private var canSelectBank: Bool {
        bankBalance > 0
    }

    private var canSelectRake: Bool {
        availableRake > 0
    }

    private var sourceFooter: some View {
        Group {
            switch payerSelection {
            case .later:
                Text("Быстрая запись: источник оплаты и распределение можно указать позже.")
            case .player:
                Text("Выбор игрока влияет на итоговые выплаты.")
            case .bank:
                if let amount = expenseAmount, amount > bankBalance {
                    Text("Недостаточно средств в кассе для полной оплаты.")
                } else {
                    Text("Расход будет оплачен из кассы сразу.")
                }
            case .rake:
                if let amount = expenseAmount, amount > availableRake {
                    Text("Недостаточно рейка для полной оплаты.")
                } else {
                    Text("Расход будет покрыт из рейка.")
                }
            case .organizers:
                if organizerDistributionMode == .none {
                    Text("Организаторы закрывают расход без вычета с игроков.")
                } else if organizerTargetPlayers.isEmpty {
                    Text("Выберите хотя бы одного игрока, чтобы списать расход из его результата.")
                } else {
                    Text("Расход будет вычтен из результатов выбранных игроков поровну.")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var organizerTargetPlayers: [Player] {
        switch organizerDistributionMode {
        case .none:
            return []
        case .allPlayers:
            return session.players
        case .selectedPlayers:
            return session.players.filter { organizerSelectedPlayerIds.contains($0.id) }
        }
    }

    private func organizerSelectionBinding(for playerId: UUID) -> Binding<Bool> {
        Binding(
            get: { organizerSelectedPlayerIds.contains(playerId) },
            set: { isSelected in
                if isSelected {
                    organizerSelectedPlayerIds.insert(playerId)
                } else {
                    organizerSelectedPlayerIds.remove(playerId)
                }
            }
        )
    }

    private var organizerDistributionByPlayerId: [UUID: Int] {
        guard let amount = expenseAmount, amount > 0 else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: organizerDistributions(for: amount).map { ($0.player.id, $0.amount) }
        )
    }

    private func organizerDistributions(for amount: Int) -> [(player: Player, amount: Int)] {
        let players = organizerTargetPlayers
        guard !players.isEmpty else { return [] }

        let baseShare = amount / players.count
        let remainder = amount % players.count

        return players.enumerated().map { index, player in
            let extra = index < remainder ? 1 : 0
            return (player: player, amount: baseShare + extra)
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddExpenseSheet(session: session)
        .modelContainer(for: [Session.self, Player.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
        .environment(SessionDetailViewModel(service: SessionService()))
}

private enum OrganizerDistributionMode {
    case none
    case allPlayers
    case selectedPlayers
}
