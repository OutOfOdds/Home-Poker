import SwiftUI
import Observation
import SwiftData

struct SettlementView: View {

    let viewModel: SettlementViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if !viewModel.bankTransfers.isEmpty {
                    Section("Выдачи из кассы") {
                        ForEach(Array(viewModel.bankTransfers.enumerated()), id: \.offset) { _, bt in
                            HStack {
                                Text("Из кассы")
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

                if !viewModel.returnTransfers.isEmpty {
                    Section("Возврат в кассу") {
                        ForEach(Array(viewModel.returnTransfers.enumerated()), id: \.offset) { _, rt in
                            HStack {
                                Text(rt.from.name)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text("В кассу")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(rt.amount.asCurrency())
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                    Text(rt.expenseNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
