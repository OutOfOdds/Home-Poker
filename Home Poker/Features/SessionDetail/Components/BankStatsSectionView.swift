import SwiftUI
import SwiftData

struct BankStatsSectionView: View {
    @Bindable var session: Session
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text("Общий закуп:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(session.totalBuyIns)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.green)
                        .fontDesign(.monospaced)
                }
                
                HStack {
                    Text("В игре:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(session.bankInGame)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .fontDesign(.monospaced)
                }
                HStack {
                    Text("Выведено:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(session.bankWithdrawn)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .fontDesign(.monospaced)
                }
            }
            if !session.expenses.isEmpty {
                NavigationLink {
                    ExpenseDetails(session: session)
                } label: {
                    HStack {
                        Text("Расходы")
                        Spacer()
                        Text("\(session.expenses.reduce(0) { $0 + $1.amount })")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
                }
            }
        }
    }
}

#Preview {
    // Сессия для превью
    let session = Session(
        startTime: Date().addingTimeInterval(-2 * 60 * 60),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem,
        status: .active
    )
    
    // Игроки и транзакции
    let p1 = Player(name: "Илья", inGame: true)
    p1.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p1),
        PlayerTransaction(type: .addOn, amount: 1000, player: p1)
    ])
    
    let p2 = Player(name: "Андрей", inGame: false)
    p2.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p2),
        PlayerTransaction(type: .cashOut, amount: 2500, player: p2) // вышел
    ])
    
    let p3 = Player(name: "Мария", inGame: true)
    p3.transactions.append(
        PlayerTransaction(type: .buyIn, amount: 1500, player: p3)
    )
    
    session.players = [p1, p2, p3]
    
    // Расходы
    let e1 = Expense(amount: 800, note: "Напитки", createdAt: Date().addingTimeInterval(-3600), payer: p1)
    let e2 = Expense(amount: 1200, note: "Закуски", createdAt: Date().addingTimeInterval(-1800), payer: p2)
    session.expenses = [e1, e2]
    
    return NavigationStack {
        List {
            BankStatsSectionView(session: session)
        }
        .navigationTitle("Превью статистики банка")
    }
    .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self], inMemory: true)
}
