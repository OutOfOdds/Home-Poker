//
//  ExpenseDistributionView.swift
//  Home Poker
//
//  View for distributing expense among players
//

import SwiftUI
import SwiftData

struct ExpenseDistributionView: View {
    @Bindable var expense: Expense
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var payerSelection: ExpensePayerSelection = .player
    @State private var selectedPayerId: UUID?
    @State private var draftPaidFromBank: Int = 0
    @State private var draftPaidFromRake: Int = 0

    // UI состояние (локальное)
    @State private var distributionMode: ExpenseDistributionMode = .equal
    @State private var playerSelections: [PlayerSelection] = []
    @State private var showInfoSheet = false

    // Computed properties
    private var totalAmount: Int {
        expense.amount
    }

    private var bankBalance: Int {
        session.bank?.netBalance ?? 0
    }

    private var remainingBankPayment: Int {
        max(expense.amount - draftPaidFromBank, 0)
    }

    private var canSelectBank: Bool {
        bankBalance > 0 || expense.paidFromBank > 0
    }

    private var canSelectRake: Bool {
        availableRake > 0 || draftPaidFromRake > 0
    }

    private var totalDistributed: Int {
        playerSelections.filter { $0.isSelected }.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Int {
        totalAmount - totalDistributed
    }

    private var isDistributionInvalid: Bool {
        if payerSelection == .rake {
            return false
        }
        // Валидация:
        // 1. Если весь расход распределен (remaining == 0) - валидно
        // 2. Если ничего не распределено (totalDistributed == 0) - тоже валидно
        //    (это значит расход полностью на организаторов, paidFromRake = 0)
        // Невалидно только если 0 < totalDistributed < expense.amount
        return remaining != 0 && totalDistributed != 0
    }

    private var isPaymentInvalid: Bool {
        switch payerSelection {
        case .player:
            return selectedPayerId == nil
        case .bank:
            return draftPaidFromBank < expense.amount
        case .rake:
            return draftPaidFromRake < expense.amount
        }
    }

    private var isFormInvalid: Bool {
        isDistributionInvalid || isPaymentInvalid
    }

    private var availableRake: Int {
        viewModel.availableRakeForExpenses(for: session)
    }

    // MARK: - Body

    var body: some View {
        Form {
            expenseInfoSection
            payerSection
            if payerSelection != .rake {
                distributionModeSection
                playerSelectionSection
                summarySection
            } else {
                Section {
                    Text("Расход покрыт организаторами, распределение между игроками не требуется.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Распределить:")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("О распределении расходов")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить", systemImage: "checkmark") {
                    submitDistribution()
                }
                .disabled(isFormInvalid)
            }
        }
        .onAppear {
            initializePlayerSelections()
            initializePayerSelection()
        }
        .onChange(of: distributionMode) { _, newMode in
            handleDistributionModeChange(newMode)
        }
        .onChange(of: payerSelection) { _, newValue in
            handlePayerSelectionChange(newValue)
        }
        .onChange(of: selectedPayerId) { _, newValue in
            handleSelectedPayerChange(newValue)
        }
        .sheet(isPresented: $showInfoSheet) {
            ExpenseDistributionInfoSheet()
        }
    }

    // MARK: - View Sections

    private var payerSection: some View {
        Section(
            header: stepHeader("Шаг 1: источник оплаты"),
            footer: payerFooter
        ) {
            Picker("Источник оплаты", selection: $payerSelection) {
                Text("Игрок").tag(ExpensePayerSelection.player)
                if canSelectBank {
                    Text("Касса").tag(ExpensePayerSelection.bank)
                }
                if canSelectRake {
                    Text("Рейк").tag(ExpensePayerSelection.rake)
                }
            }
            .pickerStyle(.segmented)

            if payerSelection == .player {
                Picker("Оплатил игрок", selection: $selectedPayerId) {
                    ForEach(session.players, id: \.id) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
            } else if payerSelection == .bank {
                if draftPaidFromBank > 0 {
                    HStack {
                        Text("Оплачено из кассы")
                        Spacer()
                        Text(draftPaidFromBank.asCurrency())
                            .fontWeight(.semibold)
                    }
                }

                HStack {
                    Text("Осталось оплатить")
                    Spacer()
                    Text(remainingBankPayment.asCurrency())
                        .fontWeight(.semibold)
                }

                if bankBalance < remainingBankPayment {
                    Text("Недостаточно средств в кассе")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else if payerSelection == .rake {
                HStack {
                    Text("Доступно рейка")
                    Spacer()
                    Text(availableRake.asCurrency())
                        .fontWeight(.semibold)
                }

                if availableRake + expense.paidFromRake < expense.amount {
                    Text("Недостаточно рейка для полной оплаты")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    private var expenseInfoSection: some View {
        Section {
            VStack(spacing: 8) {
                Text(expense.note.isEmpty ? "Расход" : expense.note)
                    .font(.headline)
                Text(totalAmount.asCurrency())
                    .font(.title)
                    .fontWeight(.bold)
                    .monospaced()
                if draftPaidFromRake > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                        Text("Покрыто организаторами (рейк): \(draftPaidFromRake.asCurrency())")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
                } else if draftPaidFromBank > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "banknote.fill")
                        Text("Оплачено из кассы: \(draftPaidFromBank.asCurrency())")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                } else if payerSelection == .player,
                          let id = selectedPayerId,
                          let payer = session.players.first(where: { $0.id == id }) {
                    Text("Оплатил: \(payer.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
        } else {
            Text("Плательщик не указан")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var distributionModeSection: some View {
        Section(
            header: stepHeader("Шаг 3: суммы"),
            footer: distributionFooter
        ) {
            Picker("Режим распределения", selection: $distributionMode) {
                Text("Поровну").tag(ExpenseDistributionMode.equal)
                Text("Вручную").tag(ExpenseDistributionMode.manual)
            }
            .pickerStyle(.segmented)
        }
    }

    private var playerSelectionSection: some View {
        Section(
            header: stepHeader("Шаг 2: участники"),
            footer: playersFooter
        ) {
            ForEach($playerSelections) { $selection in
                HStack {
                    Toggle(isOn: $selection.isSelected) {
                        HStack {
                            Text(selection.player.name)
                            if payerSelection == .player, selectedPayerId == selection.player.id {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .foregroundStyle(selection.isSelected ? .primary : .secondary)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .tint(.green)
                    .onChange(of: selection.isSelected) { _, isSelected in
                        handlePlayerSelectionChange(playerId: selection.id, isSelected: isSelected)
                    }

                    Spacer()

                    if selection.isSelected {
                        playerAmountView(for: $selection)
                    } else {
                        Text("Не участвует")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .italic()
                    }
                }
            }
        }
    }


    @ViewBuilder
    private func playerAmountView(for selection: Binding<PlayerSelection>) -> some View {
        if distributionMode == .manual {
            HStack(spacing: 4) {
                TextField("0", text: amountTextBinding(for: selection))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                Text("₽")
                    .foregroundStyle(.secondary)
            }
            .fontWeight(.semibold)
            .monospacedDigit()
        } else {
            Text(selection.wrappedValue.amount.asCurrency())
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
        }
    }

    private var summarySection: some View {
        Section(
            header: Text("Итого"),
            footer: summaryFooter
        ) {
            distributedRow
            remainingRow
        }
    }

    private var distributedRow: some View {
        HStack {
            Text("Распределено:")
            Spacer()
            Text(totalDistributed.asCurrency())
                .fontWeight(.semibold)
        }
    }

    private var remainingRow: some View {
        HStack {
            Text("Осталось распределить:")
            Spacer()
            Text(remaining.asCurrency())
                .foregroundStyle(remaining != 0 ? .red : .green)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Logic

    private func initializePlayerSelections() {
        // Если уже есть распределение - загружаем его
        if !expense.distributions.isEmpty {
            let distributionMap = Dictionary(uniqueKeysWithValues: expense.distributions.map { ($0.player.id, $0.amount) })
            playerSelections = session.players.map { player in
                let amount = distributionMap[player.id] ?? 0
                return PlayerSelection(
                    player: player,
                    isSelected: amount > 0,
                    amount: amount
                )
            }
        } else {
            // Новое распределение - все игроки не выбраны
            playerSelections = session.players.map { player in
                PlayerSelection(
                    player: player,
                    isSelected: false,
                    amount: 0
                )
            }

            // Если есть плательщик - выбираем его по умолчанию
            if let payer = expense.payer,
               let index = playerSelections.firstIndex(where: { $0.player.id == payer.id }) {
                playerSelections[index].isSelected = true
            }

            // Автоматически распределяем поровну если есть выбранные
            if playerSelections.contains(where: { $0.isSelected }) {
                distributeEqually()
            }
        }
    }

    private func initializePayerSelection() {
        if let payer = expense.payer {
            payerSelection = .player
            selectedPayerId = payer.id
        } else if expense.paidFromBank > 0 {
            payerSelection = .bank
            selectedPayerId = nil
        } else if expense.paidFromRake > 0 {
            payerSelection = .rake
            selectedPayerId = nil
        } else {
            payerSelection = .player
            selectedPayerId = session.players.first?.id
        }
        draftPaidFromBank = expense.paidFromBank
        draftPaidFromRake = expense.paidFromRake
    }

    private func handlePayerSelectionChange(_ newValue: ExpensePayerSelection) {
        switch newValue {
        case .player:
            if selectedPayerId == nil {
                selectedPayerId = session.players.first?.id
            }
            draftPaidFromRake = 0
        case .bank:
            selectedPayerId = nil
            draftPaidFromRake = 0
            draftPaidFromBank = min(expense.paidFromBank + bankBalance, expense.amount)
        case .rake:
            selectedPayerId = nil
            clearAllPlayerSelections()
            let maxPayable = availableRake + expense.paidFromRake
            draftPaidFromRake = min(maxPayable, expense.amount)
        }
    }

    private func handleSelectedPayerChange(_ newValue: UUID?) {
        guard payerSelection == .player else { return }
        selectedPayerId = newValue
    }

    private func handleDistributionModeChange(_ newMode: ExpenseDistributionMode) {
        switch newMode {
        case .equal:
            distributeEqually()
        case .manual:
            clearAmountsForSelectedPlayers()
        }
    }

    private func handlePlayerSelectionChange(playerId: UUID, isSelected: Bool) {
        if distributionMode == .equal {
            distributeEqually()
        } else {
            // Для .manual просто обнуляем, если игрок снят
            if !isSelected {
                clearPlayerValues(playerId: playerId)
            }
        }
    }

    // MARK: - Distribution Logic

    private func clearAmountsForSelectedPlayers() {
        for index in playerSelections.indices where playerSelections[index].isSelected {
            playerSelections[index].amount = 0
        }
        clearUnselectedPlayers()
    }

    private func clearUnselectedPlayers() {
        for index in playerSelections.indices where !playerSelections[index].isSelected {
            playerSelections[index].amount = 0
        }
    }

    private func clearPlayerValues(playerId: UUID) {
        guard let index = playerSelections.firstIndex(where: { $0.id == playerId }) else { return }
        playerSelections[index].amount = 0
    }

    private func distributeEqually() {
        let selectedIndices = playerSelections.indices.filter { playerSelections[$0].isSelected }
        let totalParticipants = selectedIndices.count

        guard totalParticipants > 0 else {
            clearUnselectedPlayers()
            return
        }

        let amounts = RakebackCalculator.distributeEqually(
            totalAmount: totalAmount,
            playerCount: totalParticipants
        )

        // Распределяем между игроками
        for (i, index) in selectedIndices.enumerated() {
            playerSelections[index].amount = amounts[i]
        }

        clearUnselectedPlayers()
    }

    private func amountTextBinding(for selection: Binding<PlayerSelection>) -> Binding<String> {
        Binding(
            get: {
                let amount = selection.wrappedValue.amount
                return amount == 0 ? "" : String(amount)
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                selection.wrappedValue.amount = Int(filtered) ?? 0
            }
        )
    }

    private func stepHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var payerFooter: some View {
        Group {
            if payerSelection == .player {
                Text("Оплата игроком влияет только на выбор плательщика.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var distributionFooter: some View {
        Text(distributionMode == .manual
             ? "Введите суммы для выбранных игроков."
             : "Суммы распределяются автоматически поровну.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var playersFooter: some View {
        Text("Выбрано игроков: \(playerSelections.filter { $0.isSelected }.count)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var summaryFooter: some View {
        Group {
            if isDistributionInvalid {
                Text("Нужно распределить всю сумму или оставить 0.")
            }
        }
        .font(.caption)
        .foregroundStyle(.red)
    }

    // MARK: - Submit

    private func submitDistribution() {
        let distributions: [(Player, Int)]
        if payerSelection == .rake {
            distributions = []
        } else {
            distributions = playerSelections
                .filter { $0.isSelected && $0.amount > 0 }
                .map { ($0.player, $0.amount) }
        }

        let rakeAmount = 0

        let success = viewModel.saveExpenseDistribution(
            for: expense,
            distributions: distributions,
            rakeAmount: rakeAmount
        )

        if success {
            if payerSelection != .bank && expense.paidFromBank > 0 {
                removeLinkedBankPayments()
            }

            switch payerSelection {
            case .player:
                if let id = selectedPayerId,
                   let player = session.players.first(where: { $0.id == id }) {
                    expense.payer = player
                } else {
                    expense.payer = nil
                }
                expense.paidFromRake = 0
            case .bank:
                expense.payer = nil
                expense.paidFromRake = 0
                let delta = max(draftPaidFromBank - expense.paidFromBank, 0)
                if delta > 0 {
                    _ = viewModel.payExpenseFromBank(expense: expense, amount: delta, from: session)
                }
            case .rake:
                expense.payer = nil
                expense.paidFromRake = draftPaidFromRake
            }
            dismiss()
        }
    }

    private func clearAllPlayerSelections() {
        for index in playerSelections.indices {
            playerSelections[index].isSelected = false
            playerSelections[index].amount = 0
        }
    }

    private func removeLinkedBankPayments() {
        guard let bank = session.bank else { return }
        let linked = bank.transactions.filter { transaction in
            transaction.type == .expensePayment && transaction.linkedExpense?.id == expense.id
        }
        for transaction in linked {
            _ = viewModel.deleteBankTransaction(transaction, from: session)
        }
    }

}

// MARK: - Supporting Types

private struct PlayerSelection: Identifiable {
    let id: UUID
    var player: Player
    var isSelected: Bool
    var amount: Int

    init(player: Player, isSelected: Bool, amount: Int) {
        self.id = player.id
        self.player = player
        self.isSelected = isSelected
        self.amount = amount
    }
}

private enum ExpensePayerSelection {
    case player
    case bank
    case rake
}

enum ExpenseDistributionMode {
    case equal
    case manual
}

private struct ExpenseDistributionInfoSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Зачем распределять расходы")
                            .font(.headline)
                        Text("Этот экран помогает учесть расходы, которые уменьшают итоговые выплаты игрокам. Распределение позволяет корректно рассчитать, кто и сколько фактически должен получить или доплатить.")
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("Какие расходы нужно добавлять")
                            .font(.headline)
                        Text("Добавляйте только общие расходы, которые влияют на выплаты между игроками. Личные траты (например, еда для себя) не нужно записывать.")
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("Источник оплаты")
                            .font(.headline)
                        Text("Выберите, кто оплатил расход: игрок, касса или рейк. Это влияет на баланс сессии и итоговые выплаты.")
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("Кого включать")
                            .font(.headline)
                        Text("Отметьте игроков, на которых делится расход. Если игрок не участвует, на его выплату это не влияет.")
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("Режимы распределения")
                            .font(.headline)
                        Text("Поровну — сумма делится автоматически. Вручную — можно задать точные значения для каждого игрока.")
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("Как это влияет на выплаты")
                            .font(.headline)
                        Text("Сумма расходов уменьшает итоговые выплаты выбранным игрокам. Если расход оплачен из кассы или рейка, важно корректно распределить его между участниками.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("О распределении расходов")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    let session = PreviewData.activeSession()
    let expense = session.expenses.first ?? Expense(amount: 2000, note: "Пицца", payer: session.players.first)
    session.expenses.append(expense)

    return NavigationStack {
        ExpenseDistributionView(expense: expense, session: session)
            .environment(SessionDetailViewModel())
            .modelContainer(
                for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, ExpenseDistribution.self, SessionBank.self, SessionBankTransaction.self],
                inMemory: true
            )
    }
}
