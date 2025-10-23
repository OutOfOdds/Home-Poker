import SwiftUI
import SwiftData

struct PlayerTransactionsView: View {
    let player: Player

    var body: some View {
        List {
            if player.transactions.isEmpty {
                ContentUnavailableView("Нет транзакций", systemImage: "creditcard")
            } else {
                ForEach(player.transactions.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { transaction in
                    HStack {
                        Text(transactionTypeDisplay(transaction.type))
                            .fontWeight(.medium)
                        Spacer()
                        Text(transaction.amount.asCurrency())
                            .foregroundColor(.secondary)
                        Text(transaction.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func transactionTypeDisplay(_ type: TransactionType) -> String {
        switch type {
        case .buyIn: return "Закупка"
        case .addOn: return "Докупка"
        case .cashOut: return "Вывод"
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()
    let player = session.players.first ?? PreviewData.activePlayer()
    return NavigationStack {
        PlayerTransactionsView(player: player)
    }
    .modelContainer(PreviewData.previewContainer)
}
