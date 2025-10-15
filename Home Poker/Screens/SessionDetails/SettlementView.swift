import SwiftUI
import Observation

struct SettlementView: View {
    @Bindable var session: Session
    @Environment(\.dismiss) private var dismiss
    
    private var viewModel: SettlementViewModel {
        SettlementViewModel(session: session)
    }
    
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
                                }
                                Spacer()
                                Text("\(balance.net)")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(balance.net >= 0 ? .green : .red)
                            }
                        }
                    }
                }
                
                Section("Переводы") {
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
                                Text("\(t.amount)")
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
