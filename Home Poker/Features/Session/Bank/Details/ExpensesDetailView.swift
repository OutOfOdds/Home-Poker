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

                    if expense.isFullyDistributed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    Text(expense.note.isEmpty ? "Расход" : expense.note)
                        .font(.body)
                }

                if let payerName = expense.payer?.name {
                    Text("Оплатил: \(payerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if expense.paidFromRake > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote.fill")
                            .font(.caption2)
                        Text("Оплачено из рейка: \(expense.paidFromRake.asCurrency())")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }

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

    // MARK: - Кнопки тулбара

    private var addExpenseButton: some View {
        Button {
            showingAddExpenseSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .disabled(session.players.isEmpty)
    }
}

#Preview("With Expenses") {
    NavigationStack {
        ExpensesDetailView(session: PreviewData.sessionWithFullBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, Expense.self, ExpenseDistribution.self],
        inMemory: true
    )
}

#Preview("No Expenses") {
    NavigationStack {
        ExpensesDetailView(session: PreviewData.sessionWithBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, Expense.self],
        inMemory: true
    )
}
