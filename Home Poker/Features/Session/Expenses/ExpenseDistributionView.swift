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

    // UI состояние (локальное)
    @State private var distributionMode: ExpenseDistributionMode = .equal
    @State private var playerSelections: [PlayerSelection] = []

    // Для редактирования значений
    @State private var editingPlayerId: UUID?
    @State private var showEditAlert = false
    @State private var editValue = ""

    // Computed properties
    private var totalAmount: Int {
        expense.amount
    }

    private var totalDistributed: Int {
        playerSelections.filter { $0.isSelected }.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Int {
        totalAmount - totalDistributed
    }

    private var editingPlayer: PlayerSelection? {
        guard let id = editingPlayerId else { return nil }
        return playerSelections.first { $0.id == id }
    }

    private var isDistributionInvalid: Bool {
        if totalDistributed == 0 {
            return true
        }
        if remaining != 0 {
            return true
        }
        return false
    }

    // MARK: - Body

    var body: some View {
        Form {
            expenseInfoSection
            distributionModeSection
            playerSelectionSection
            summarySection
        }
        .navigationTitle("Распределить расход")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    submitDistribution()
                }
                .disabled(isDistributionInvalid)
            }
        }
        .onAppear {
            initializePlayerSelections()
        }
        .onChange(of: distributionMode) { _, newMode in
            handleDistributionModeChange(newMode)
        }
        .alert(editingPlayer?.player.name ?? "", isPresented: $showEditAlert) {
            TextField("Сумма", text: $editValue)
                .keyboardType(.numberPad)
            Button("Отмена", role: .cancel) {
                editingPlayerId = nil
                editValue = ""
            }
            Button("Сохранить") {
                saveEditedValue()
            }
        } message: {
            Text("Осталось: \(remaining.asCurrency())")
        }
    }

    // MARK: - View Sections

    private var expenseInfoSection: some View {
        Section {
            VStack(spacing: 8) {
                Text(expense.note.isEmpty ? "Расход" : expense.note)
                    .font(.headline)
                Text(totalAmount.asCurrency())
                    .font(.title)
                    .fontWeight(.bold)
                if let payer = expense.payer {
                    Text("Оплатил: \(payer.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var distributionModeSection: some View {
        Section {
            Picker("Режим распределения", selection: $distributionMode) {
                Text("Поровну").tag(ExpenseDistributionMode.equal)
                Text("Вручную").tag(ExpenseDistributionMode.manual)
            }
            .pickerStyle(.segmented)
        }
    }

    private var playerSelectionSection: some View {
        Section("Кто участвует в оплате?") {
            ForEach($playerSelections) { $selection in
                HStack {
                    Toggle(isOn: $selection.isSelected) {
                        HStack {
                            Text(selection.player.name)
                            if let payer = expense.payer, payer.id == selection.player.id {
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
                        playerAmountView(for: selection)
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
    private func playerAmountView(for selection: PlayerSelection) -> some View {
        if distributionMode == .manual {
            Button {
                openEditAlert(for: selection)
            } label: {
                HStack(spacing: 4) {
                    Text(selection.amount.asCurrency())
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .fontWeight(.semibold)
            }
        } else {
            Text(selection.amount.asCurrency())
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
        }
    }

    private var summarySection: some View {
        Section("Итого") {
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
            Text("Осталось:")
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
        guard !selectedIndices.isEmpty else {
            clearUnselectedPlayers()
            return
        }

        let amounts = RakebackCalculator.distributeEqually(
            totalAmount: totalAmount,
            playerCount: selectedIndices.count
        )

        for (i, index) in selectedIndices.enumerated() {
            playerSelections[index].amount = amounts[i]
        }

        clearUnselectedPlayers()
    }

    // MARK: - Edit Alert

    private func openEditAlert(for selection: PlayerSelection) {
        editingPlayerId = selection.id
        editValue = "\(selection.amount)"
        showEditAlert = true
    }

    private func saveEditedValue() {
        guard let playerId = editingPlayerId,
              let index = playerSelections.firstIndex(where: { $0.id == playerId }),
              let value = Int(editValue) else {
            editingPlayerId = nil
            editValue = ""
            return
        }

        playerSelections[index].amount = value

        editingPlayerId = nil
        editValue = ""
    }

    // MARK: - Submit

    private func submitDistribution() {
        let distributions = playerSelections
            .filter { $0.isSelected && $0.amount > 0 }
            .map { ($0.player, $0.amount) }

        let success = viewModel.saveExpenseDistribution(
            for: expense,
            distributions: distributions
        )

        if success {
            dismiss()
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

enum ExpenseDistributionMode {
    case equal
    case manual
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
