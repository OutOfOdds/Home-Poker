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

#Preview {
    let session = Session(
        startTime: Date().addingTimeInterval(-3600),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem,
        status: .active
    )
    
    let p1 = Player(name: "Илья", inGame: false)
    let p2 = Player(name: "Андрей", inGame: true)
    let p3 = Player(name: "Мария", inGame: false)
    
    let p1BuyIn = PlayerTransaction(type: .buyIn, amount: 2000, player: p1)
    let p1CashOut = PlayerTransaction(type: .cashOut, amount: 3200, player: p1)
    p1.transactions.append(contentsOf: [p1BuyIn, p1CashOut])
    
    let p2BuyIn = PlayerTransaction(type: .buyIn, amount: 2500, player: p2)
    let p2AddOn = PlayerTransaction(type: .addOn, amount: 500, player: p2)
    p2.transactions.append(contentsOf: [p2BuyIn, p2AddOn])
    
    let p3BuyIn = PlayerTransaction(type: .buyIn, amount: 1500, player: p3)
    let p3CashOut = PlayerTransaction(type: .cashOut, amount: 2200, player: p3)
    p3.transactions.append(contentsOf: [p3BuyIn, p3CashOut])
    
    session.players.append(contentsOf: [p1, p2, p3])
    
    // Для превью считаем VM здесь
    let vm = SettlementViewModel(session: session)
    
    return SettlementView(viewModel: vm)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
            inMemory: true
        )
}
