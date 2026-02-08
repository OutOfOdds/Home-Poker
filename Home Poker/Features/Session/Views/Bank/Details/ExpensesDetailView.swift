//
//  ExpensesDetailView.swift
//  Home Poker
//
//  Детальный экран расходов
//  Содержит список расходов и функционал добавления новых
//

import SwiftUI
import SwiftData

struct ExpensesDetailView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var showingAddExpenseSheet = false
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false

    private var sortedExpenses: [Expense] {
        session.expenses.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalExpenses: Int {
        session.expenses.reduce(0) { $0 + $1.amount }
    }

    private var distributedExpenses: Int {
        session.expenses.filter { $0.isFullyDistributed }.reduce(0) { $0 + $1.amount }
    }

    private var undistributedExpenses: Int {
        totalExpenses - distributedExpenses
    }

    private var expensesPaidFromRake: Int {
        session.expenses.reduce(0) { $0 + $1.paidFromRake }
    }

    var body: some View {
        List {
            if !sortedExpenses.isEmpty {
                summarySection
            }

            expensesSection

            if sortedExpenses.isEmpty {
                ContentUnavailableView(
                    "Нет расходов",
                    systemImage: "cart",
                    description: Text("Добавьте расход, нажав кнопку + выше")
                )
            }
        }
        .navigationTitle("Расходы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addExpenseButton
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            NavigationStack {
                AddExpenseSheet(session: session)
                    .environment(viewModel)
            }
        }
        .alert("Удалить расход?", isPresented: $showingDeleteConfirmation, presenting: expenseToDelete) { expense in
            Button("Отмена", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                viewModel.removeExpenses([expense], from: session)
                expenseToDelete = nil
            }
        } message: { expense in
            Text("Расход «\(expense.note.isEmpty ? "Без описания" : expense.note)» на сумму \(expense.amount.asCurrency()) будет удалён.")
        }
    }

    // MARK: - Секции

    private var summarySection: some View {
        Section("Итоги") {
            HStack {
                Text("Всего расходов")
                Spacer()
                Text(totalExpenses.asCurrency())
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospaced()

            }

            HStack {
                Text("Распределено")
                Spacer()
                Text(distributedExpenses.asCurrency())
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .monospaced()

            }

            if undistributedExpenses > 0 {
                HStack {
                    Text("Не распределено")
                    Spacer()
                    Text(undistributedExpenses.asCurrency())
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .monospaced()

                }
            }

            if expensesPaidFromRake > 0 {
                HStack {
                    Text("Оплачено из рейка")
                    Spacer()
                    Text(expensesPaidFromRake.asCurrency())
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .monospaced()
                }
            }
        }
    }

    private var expensesSection: some View {
        Section("Список расходов (\(sortedExpenses.count))") {
            if sortedExpenses.isEmpty {
                Text("Пока нет расходов")
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
                    .monospaced()

            } else {
                ForEach(sortedExpenses, id: \.id) { expense in
                    NavigationLink {
                        ExpenseDistributionView(expense: expense, session: session)
                            .environment(viewModel)
                    } label: {
                        expenseRow(expense)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            expenseToDelete = expense
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Строки

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {

                    Image(systemName: distributionIcon(for: expense))
                        .font(.caption2)
                        .foregroundStyle(distributionColor(for: expense))

                    Text(expense.note.isEmpty ? "Расход" : expense.note)
                        .font(.body)
                }

                sourceStatusView(expense)
                distributionStatusView(expense)

                Text(expense.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(expense.amount.asCurrency())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospaced()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sourceStatusView(_ expense: Expense) -> some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIcon(for: expense))
                .font(.caption2)
            Text(expense.sourceStatusText)
        }
        .font(.caption2)
        .foregroundStyle(sourceColor(for: expense))
    }

    @ViewBuilder
    private func distributionStatusView(_ expense: Expense) -> some View {
        HStack(spacing: 4) {
            Image(systemName: distributionIcon(for: expense))
                .font(.caption2)
            Text(expense.distributionStatusText)
        }
        .font(.caption2)
        .foregroundStyle(distributionColor(for: expense))
    }

    private func sourceIcon(for expense: Expense) -> String {
        switch expense.resolvedSource {
        case .later:
            return "questionmark.circle"
        case .player:
            return "person.fill"
        case .bank:
            return "banknote.fill"
        case .rake:
            return "dollarsign.circle.fill"
        case .organizers:
            return "person.3.sequence.fill"
        }
    }

    private func sourceColor(for expense: Expense) -> Color {
        if expense.requiresReview {
            return .red
        }
        switch expense.resolvedSource {
        case .later, .player:
            return .secondary
        case .bank:
            return .green
        case .rake:
            return .blue
        case .organizers:
            return .purple
        }
    }

    private func distributionIcon(for expense: Expense) -> String {
        switch expense.distributionState {
        case .notRequired, .distributed:
            return "checkmark.circle.fill"
        case .needsDistribution:
            return "exclamationmark.circle.fill"
        case .needsReview:
            return "xmark.octagon.fill"
        }
    }

    private func distributionColor(for expense: Expense) -> Color {
        switch expense.distributionState {
        case .notRequired, .distributed:
            return .green
        case .needsDistribution:
            return .orange
        case .needsReview:
            return .red
        }
    }

    // MARK: - Кнопки тулбара

    private var addExpenseButton: some View {
        Button {
            showingAddExpenseSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
}

#Preview("All Use Cases") {
    @Previewable @State var container = try! ModelContainer(
        for: Session.self, Player.self, Expense.self, ExpenseDistribution.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let session = Session(startTime: Date(), location: "Test", gameType: .NLHoldem, sessionType: .cash, status: .active, sessionTitle: "Test Session")
    let player1 = Player(name: "Игрок 1")
    let player2 = Player(name: "Игрок 2")

    session.players = [player1, player2]

    // 1. Не распределен (оранжевый флаг)
    let expense1 = Expense(amount: 3000, note: "Не распределен", payer: nil, paidFromRake: 0, paidFromBank: 0)

    // 2. Взято на организаторов (зеленый флаг, синий текст)
    let expense2 = Expense(amount: 2000, note: "Взято на организаторов", payer: nil, paidFromRake: 2000, paidFromBank: 0)

    // 3. Распределен между игроками (зеленый флаг)
    let expense3 = Expense(amount: 4000, note: "Распределен", payer: nil, paidFromRake: 0, paidFromBank: 0)
    let dist3_1 = ExpenseDistribution(amount: 2000, player: player1, expense: expense3)
    let dist3_2 = ExpenseDistribution(amount: 2000, player: player2, expense: expense3)
    expense3.distributions = [dist3_1, dist3_2]

    // 4. Оплачен из кассы и распределен (зеленый флаг, зеленая иконка)
    let expense4 = Expense(amount: 5000, note: "Оплачен из кассы", payer: nil, paidFromRake: 0, paidFromBank: 5000)
    let dist4_1 = ExpenseDistribution(amount: 2500, player: player1, expense: expense4)
    let dist4_2 = ExpenseDistribution(amount: 2500, player: player2, expense: expense4)
    expense4.distributions = [dist4_1, dist4_2]

    // 5. С плательщиком (зеленый флаг, показывает плательщика)
    let expense5 = Expense(amount: 1500, note: "С плательщиком", payer: player1, paidFromRake: 0, paidFromBank: 0)
    let dist5_1 = ExpenseDistribution(amount: 750, player: player1, expense: expense5)
    let dist5_2 = ExpenseDistribution(amount: 750, player: player2, expense: expense5)
    expense5.distributions = [dist5_1, dist5_2]

    session.expenses = [expense1, expense2, expense3, expense4, expense5]

    container.mainContext.insert(session)

    return NavigationStack {
        ExpensesDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(container)
}
