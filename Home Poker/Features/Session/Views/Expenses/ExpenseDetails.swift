import SwiftUI
import SwiftData

struct ExpenseDetails: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    var body: some View {
        Group {
            if session.expenses.isEmpty {
                ContentUnavailableView("Расходов пока нет", systemImage: "cart")
            } else {
                List {
                    // Секция расходов
                    Section {
                        ForEach(expensesSorted, id: \.id) { expense in
                            ExpenseRow(expense: expense, session: session)
                        }
                        .onDelete(perform: delete)
                    } header: {
                        HStack {
                            Text("Расходы (\(session.expenses.count))")
                            Spacer()
                            Text("Итого: \(totalAmount.asCurrency())")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .fontDesign(.monospaced)
                    }
                    
                    // Секция игроков и их взносов в расходы
                    Section {
                        ForEach(playersSorted, id: \.id) { player in
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(contributedAmount(for: player).asCurrency())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        Text("Кто оплатил")
                            .font(.caption)
                    } footer: {
                        HStack {
                            Text("Всего оплачено игроками")
                            Spacer()
                            Text(totalAmount.asCurrency())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Расходы")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var expensesSorted: [Expense] {
        session.expenses.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var playersSorted: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var totalAmount: Int {
        session.expenses.reduce(0) { $0 + $1.amount }
    }
    
    private func contributedAmount(for player: Player) -> Int {
        session.expenses
            .filter { $0.payer?.id == player.id }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func delete(at offsets: IndexSet) {
        let expensesToRemove = offsets.map { expensesSorted[$0] }
        viewModel.removeExpenses(expensesToRemove, from: session)
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let session: Session

    var body: some View {
        NavigationLink {
            ExpenseDistributionView(expense: expense, session: session)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(expense.note.isEmpty ? "Без описания" : expense.note)
                            .font(.body)
                        Image(systemName: distributionIcon(for: expense))
                            .font(.caption)
                            .foregroundStyle(distributionColor(for: expense))
                    }

                    HStack(spacing: 6) {
                        Text(expense.sourceStatusText)
                        Text(expense.createdAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(sourceColor(for: expense))

                    Text(expense.distributionStatusText)
                        .font(.caption2)
                        .foregroundStyle(distributionColor(for: expense))
                }
                Spacer()
                Text(expense.amount.asCurrency())
                    .font(.body.weight(.semibold))
            }
            .padding(.vertical, 4)
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
}

#Preview {
    let session = PreviewData.activeSession()

    return NavigationStack {
        ExpenseDetails(session: session)
    }
    .modelContainer(for: [Session.self, Player.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
    .environment(SessionDetailViewModel())
}
