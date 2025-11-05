import SwiftUI
import Observation
import SwiftData

struct SettlementView: View {

    let viewModel: SettlementViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Балансы") {
                    if viewModel.balances.isEmpty {
                        Text("Нет данных по игрокам")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.balances, id: \.player.id) { balance in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(balance.player.name)
                                        .font(.headline)
                                    Text("Закуп: \(balance.buyIn) • Вывод: \(balance.cashOut)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(balance.netChips >= 0 ? "+" : "")\(balance.netChips) фишек")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(balance.netCash.asCurrency())
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(balance.netCash >= 0 ? .green : .red)
                            }
                        }
                    }
                }

                if !viewModel.bankTransfers.isEmpty {
                    Section("Переводы через банк") {
                        ForEach(Array(viewModel.bankTransfers.enumerated()), id: \.offset) { _, bt in
                            HStack {
                                Text("Из банка")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text(bt.to.name)
                                Spacer()
                                Text(bt.amount.asCurrency())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Section("Прямые переводы") {
                    if viewModel.transfers.isEmpty {
                        Text("Переводы не требуются")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.transfers.enumerated()), id: \.offset) { _, t in
                            HStack {
                                Text(t.from.name)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text(t.to.name)
                                Spacer()
                                Text(t.amount.asCurrency())
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Рассчет")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let session = PreviewData.finishedSession()
    let vm = SettlementViewModel(session: session)

    SettlementView(viewModel: vm)
        .modelContainer(
            for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
}
