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
                            ExpenseRow(expense: expense)
                        }
                        .onDelete(perform: delete)
                    } header: {
                        HStack {
                            Text("Расходы (\(session.expenses.count))")
                            Spacer()
                            Text("Итого: ₽\(totalAmount)")
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
                                Text("₽\(contributedAmount(for: player))")
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
                            Text("₽\(totalAmount)")
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
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.note.isEmpty ? "Без описания" : expense.note)
                    .font(.body)
                HStack(spacing: 6) {
                    if let payerName = expense.payer?.name {
                        Text(payerName)
                    }
                    Text(expense.createdAt, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("₽\(expense.amount)")
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let session = Session(
        startTime: Date().addingTimeInterval(-60 * 60 * 3),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem,
        status: .active
    )
    let p1 = Player(name: "Илья", inGame: true)
    let p2 = Player(name: "Андрей", inGame: true)
    session.players = [p1, p2]
    
    let e1 = Expense(amount: 800, note: "Напитки", createdAt: Date().addingTimeInterval(-3600), payer: p1)
    let e2 = Expense(amount: 1200, note: "Закуски", createdAt: Date().addingTimeInterval(-1800), payer: p2)
    session.expenses = [e1, e2]
    
    return NavigationStack {
        ExpenseDetails(session: session)
    }
    .modelContainer(for: [Session.self, Player.self, Expense.self], inMemory: true)
    .environment(SessionDetailViewModel())
}
