import SwiftUI

struct BankStatsSectionView: View {
    @Bindable var session: Session
    
    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text("Общий закуп")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.totalBuyIns)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .center) {
                    Text("В игре")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.bankInGame)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Выведено")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.bankWithdrawn)")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(.orange)
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
                }
            }
        }
    }
}
