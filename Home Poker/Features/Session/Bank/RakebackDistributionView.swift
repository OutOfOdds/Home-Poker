//
//  RakebackDistributionView.swift
//  Home Poker
//
//  View for distributing rakeback among players
//

import SwiftUI
import SwiftData

struct RakebackDistributionView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    // UI состояние (локальное)
    @State private var distributionMode: DistributionMode = .equal
    @State private var playerSelections: [PlayerSelection] = []

    // Для редактирования значений
    @State private var editingPlayerId: UUID?
    @State private var showEditAlert = false
    @State private var editValue = ""

    // Computed properties
    private var totalAvailable: Int {
        viewModel.availableRakebackAmount(for: session)
    }

    private var totalDistributed: Int {
        playerSelections.filter { $0.isSelected }.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Int {
        totalAvailable - totalDistributed
    }

    private var totalPercentage: Int {
        playerSelections.filter { $0.isSelected }.reduce(0) { $0 + $1.percentage }
    }

    private var percentageRemaining: Int {
        100 - totalPercentage
    }

    private var percentageRemainingText: String {
        if totalPercentage > 100 {
            return "Превышено:"
        } else if totalPercentage < 100 {
            return "Дом оставит себе:"
        } else {
            return "Распределено полностью:"
        }
    }

    private var percentageRemainingColor: Color {
        if totalPercentage > 100 {
            return .red
        } else if totalPercentage < 100 {
            return .orange
        } else {
            return .green
        }
    }

    private var editingPlayer: PlayerSelection? {
        guard let id = editingPlayerId else { return nil }
        return playerSelections.first { $0.id == id }
    }

    private var isDistributionInvalid: Bool {
        if totalDistributed == 0 {
            return true
        }
        if remaining < 0 {
            return true
        }
        if distributionMode == .percentage && totalPercentage > 100 {
            return true
        }
        return false
    }

    // MARK: - Body

    var body: some View {
        Form {
            availableSection
            distributionModeSection
            playerSelectionSection
            summarySection
        }
        .navigationTitle("Рейкбек")
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
            TextField(distributionMode == .percentage ? "Процент" : "Сумма", text: $editValue)
                .keyboardType(.numberPad)
            Button("Отмена", role: .cancel) {
                editingPlayerId = nil
                editValue = ""
            }
            Button("Сохранить") {
                saveEditedValue()
            }
        } message: {
            if distributionMode == .percentage {
                Text("Осталось распределить: \(percentageRemaining)%")
            } else {
                Text("Осталось: \(remaining.asCurrency())")
            }
        }
    }

    // MARK: - View Sections

    private var availableSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("Доступно для распределения")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(totalAvailable.asCurrency())
                    .font(.title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var distributionModeSection: some View {
        Section {
            Picker("Режим распределения", selection: $distributionMode) {
                Text("Поровну").tag(DistributionMode.equal)
                Text("По %").tag(DistributionMode.percentage)
                Text("Вручную").tag(DistributionMode.manual)
            }
            .pickerStyle(.segmented)
        }
    }

    private var playerSelectionSection: some View {
        Section("Кто претендует на рейкбек?") {
            ForEach($playerSelections) { $selection in
                HStack {
                    Toggle(isOn: $selection.isSelected) {
                        Text(selection.player.name)
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
        if distributionMode == .percentage || distributionMode == .manual {
            VStack(spacing: 2) {
                Button {
                    openEditAlert(for: selection)
                } label: {
                    HStack(spacing: 4) {
                        if distributionMode == .percentage {
                            Text("\(selection.percentage)%")
                        } else {
                            Text(selection.amount.asCurrency())
                        }
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .fontWeight(.semibold)
                }

                Text(selection.amount.asCurrency())
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .italic()
            }
        } else {
            Text(selection.amount.asCurrency())
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
        }
    }

    private var summarySection: some View {
        Section("Итого") {
            if distributionMode == .percentage {
                percentageRow
                percentageRemainingRow
            }
            distributedRow
            remainingRow
        }
    }

    private var percentageRow: some View {
        HStack {
            Text("Проценты:")
            Spacer()
            Text("\(totalPercentage)%")
                .foregroundStyle(percentageRowColor)
                .fontWeight(.semibold)
        }
    }

    private var percentageRowColor: Color {
        if totalPercentage > 100 {
            return .red
        } else if totalPercentage < 100 {
            return .orange
        } else {
            return .green
        }
    }

    private var percentageRemainingRow: some View {
        HStack {
            Text(percentageRemainingText)
            Spacer()
            Text("\(abs(percentageRemaining))%")
                .foregroundStyle(percentageRemainingColor)
                .fontWeight(.semibold)
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
                .foregroundStyle(remaining < 0 ? .red : .secondary)
                .fontWeight(.semibold)
        }
    }


    // MARK: - Logic

    private func initializePlayerSelections() {
        playerSelections = session.players.map { player in
            PlayerSelection(
                player: player,
                isSelected: player.getsRakeback,
                amount: player.rakeback,
                percentage: 0
            )
        }

        // Если есть сохраненное распределение, восстанавливаем режим
        let hasRakeback = session.players.contains { $0.getsRakeback && $0.rakeback > 0 }
        if hasRakeback {
            // Можно восстановить режим или оставить равное распределение
            // Пока оставляем как есть
        } else if totalAvailable > 0 {
            // Первый раз - распределяем поровну
            distributeEqually()
        }
    }

    private func handleDistributionModeChange(_ newMode: DistributionMode) {
        switch newMode {
        case .equal:
            distributeEqually()
        case .percentage:
            clearAmountsForSelectedPlayers()
        case .manual:
            clearAmountsForSelectedPlayers()
        }
    }

    private func handlePlayerSelectionChange(playerId: UUID, isSelected: Bool) {
        if distributionMode == .equal {
            distributeEqually()
        } else {
            // Для .percentage и .manual просто обнуляем, если игрок снят
            if !isSelected {
                clearPlayerValues(playerId: playerId)
            }
        }
    }

    // MARK: - Distribution Logic (UI-only calculations)

    /// Обнуляет суммы и проценты для выбранных игроков, сохраняя их выбор
    private func clearAmountsForSelectedPlayers() {
        for index in playerSelections.indices where playerSelections[index].isSelected {
            playerSelections[index].amount = 0
            playerSelections[index].percentage = 0
        }
        clearUnselectedPlayers()
    }

    private func clearUnselectedPlayers() {
        for index in playerSelections.indices where !playerSelections[index].isSelected {
            playerSelections[index].amount = 0
            playerSelections[index].percentage = 0
        }
    }

    /// Обнуляет проценты и суммы для конкретного игрока
    private func clearPlayerValues(playerId: UUID) {
        guard let index = playerSelections.firstIndex(where: { $0.id == playerId }) else { return }
        playerSelections[index].percentage = 0
        playerSelections[index].amount = 0
    }

    private func distributeEqually() {
        let selectedIndices = playerSelections.indices.filter { playerSelections[$0].isSelected }
        guard !selectedIndices.isEmpty else {
            clearUnselectedPlayers()
            return
        }

        let amounts = RakebackCalculator.distributeEqually(
            totalAmount: totalAvailable,
            playerCount: selectedIndices.count
        )

        for (i, index) in selectedIndices.enumerated() {
            playerSelections[index].amount = amounts[i]
        }

        clearUnselectedPlayers()
    }


    private func recalculateAmountsFromPercentages() {
        let selectedIndices = playerSelections.indices.filter { playerSelections[$0].isSelected }
        let percentages = selectedIndices.map { playerSelections[$0].percentage }
        let amounts = RakebackCalculator.distributeByPercentage(
            totalAmount: totalAvailable,
            percentages: percentages
        )

        for (i, index) in selectedIndices.enumerated() {
            playerSelections[index].amount = amounts[i]
        }

        clearUnselectedPlayers()
    }

    // MARK: - Edit Alert

    private func openEditAlert(for selection: PlayerSelection) {
        editingPlayerId = selection.id
        if distributionMode == .percentage {
            editValue = "\(selection.percentage)"
        } else {
            editValue = "\(selection.amount)"
        }
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

        if distributionMode == .percentage {
            playerSelections[index].percentage = value
            recalculateAmountsFromPercentages()
        } else {
            playerSelections[index].amount = value
        }

        editingPlayerId = nil
        editValue = ""
    }

    // MARK: - Submit

    private func submitDistribution() {
        let distributions = playerSelections
            .filter { $0.isSelected && $0.amount > 0 }
            .map { ($0.player, $0.amount) }

        let success = viewModel.saveRakebackDistribution(
            for: session,
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
    var percentage: Int

    init(player: Player, isSelected: Bool, amount: Int, percentage: Int) {
        self.id = player.id
        self.player = player
        self.isSelected = isSelected
        self.amount = amount
        self.percentage = percentage
    }
}

// MARK: - Preview

#Preview {
    let session = PreviewData.activeSession()
    return NavigationStack {
        RakebackDistributionView(session: session)
            .environment(SessionDetailViewModel())
            .modelContainer(
                for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
                inMemory: true
            )
    }
}
