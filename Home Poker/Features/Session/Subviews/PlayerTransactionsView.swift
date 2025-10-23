import SwiftUI
import SwiftData

struct PlayerTransactionsView: View {
    let player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var transactionToDelete: PlayerTransaction?
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            if player.transactions.isEmpty {
                ContentUnavailableView("Нет транзакций", systemImage: "creditcard")
            } else {
                ForEach(sortedTransactions, id: \.id) { transaction in
                    HStack(spacing: 12) {
                        transactionIcon(for: transaction.type)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transactionTypeDisplay(transaction.type))
                                .fontWeight(.semibold)
                            Text(transaction.timestamp, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(transaction.amount.asCurrency())
                            .font(.headline)
                            .foregroundStyle(color(for: transaction.type))
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            transactionToDelete = transaction
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.large)
        .alert("Удалить транзакцию?", isPresented: $showDeleteAlert, presenting: transactionToDelete) { transaction in
            Button("Удалить", role: .destructive) {
                withAnimation {
                    viewModel.removeTransaction(transaction, from: session)
                }
            }
            Button("Отмена", role: .cancel) {
                transactionToDelete = nil
            }
        } message: { transaction in
            Text("\(transactionTypeDisplay(transaction.type)) на сумму \(transaction.amount.asCurrency()) будет удалена.")
        }
    }

    private func transactionTypeDisplay(_ type: TransactionType) -> String {
        switch type {
        case .buyIn: return "Закупил фишек"
        case .addOn: return "Докупил фишек"
        case .cashOut: return "Вывел фишки"
        }
    }

    private func transactionIcon(for type: TransactionType) -> some View {
        Image(systemName: iconName(for: type))
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color(for: type), in: Circle())
    }

    private func iconName(for type: TransactionType) -> String {
        switch type {
        case .buyIn: return "figure.walk.arrival"
        case .addOn: return "plus.circle.fill"
        case .cashOut: return "figure.walk.departure"
        }
    }

    private func color(for type: TransactionType) -> Color {
        switch type {
        case .buyIn: return .purple
        case .addOn: return .green
        case .cashOut: return .orange
        }
    }

    private var sortedTransactions: [PlayerTransaction] {
        player.transactions.sorted { $0.timestamp > $1.timestamp }
    }
}

#Preview {
    let session = PreviewData.activeSession()
    let player = session.players.first ?? PreviewData.activePlayer()
    return NavigationStack {
        PlayerTransactionsView(player: player, session: session)
    }
    .modelContainer(PreviewData.previewContainer)
    .environment(SessionDetailViewModel())
}
