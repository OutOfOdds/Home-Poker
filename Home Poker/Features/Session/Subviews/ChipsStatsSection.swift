import SwiftUI
import SwiftData

struct ChipsStatsSection: View {
    @Bindable var session: Session
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Игроки:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("активные / всего")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(session.activePlayers.count)/\(session.players.count)")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.brown)
                        .fontDesign(.monospaced)
                }
                
                Line()
                    .stroke(style: .init(dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: 1)

                
                HStack {
                    Text("Общий закуп:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(session.totalChips)")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .fontDesign(.monospaced)
                }

                Line()
                    .stroke(style: .init(dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: 1)

                HStack {
                    Text("В игре:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(session.chipsInGame)")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .fontDesign(.monospaced)
                }
                
                Line()
                    .stroke(style: .init(dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: 1)

                HStack {
                    Text("Выведено:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(session.chipsWithdrawn)")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .fontDesign(.monospaced)
                }
            }
            .italic()
            .fontDesign(.monospaced)

            if !session.expenses.isEmpty {
                NavigationLink {
                    ExpenseDetails(session: session)
                } label: {
                    HStack {
                        Image(systemName: "cart.fill.badge.plus")
                        Text("Расходы")
                        Spacer()
                        Text(session.expenses.reduce(0) { $0 + $1.amount }.asCurrency())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
                }
            }
            
            NavigationLink {
                SessionBankView(session: session)
            } label: {
                HStack {
                    Image(systemName: "building.columns")
                    Text("Банк сессии")
                    Spacer()
                    if let bank = session.bank {
                        if bank.totalOwedByBank > 0 {
                            Text("К выплате: \(bank.totalOwedByBank.asCurrency())")
                                .fontDesign(.monospaced)
                                .foregroundStyle(.blue)
                        } else if bank.remainingToCollect > 0 {
                            Text("Долг банку: \(bank.remainingToCollect.asCurrency())")
                                .fontDesign(.monospaced)
                                .foregroundStyle(.red)
                        } else {
                            Text("Расчёты закрыты")
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Создать")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
            }
        }
    }
}

struct Line:Shape{
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

#Preview {
    let session = PreviewData.activeSession()

    NavigationStack {
        List {
            ChipsStatsSection(session: session)
        }
        .navigationTitle("Превью статистики банка")
    }
    .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
    .environment(SessionDetailViewModel())
}
