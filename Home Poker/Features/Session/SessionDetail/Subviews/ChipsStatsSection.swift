import SwiftUI
import SwiftData

struct ChipsStatsSection: View {
    @Bindable var session: Session
    @Binding var showingRakeSheet: Bool
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    private var allPlayersFinished: Bool {
        !session.players.isEmpty && session.players.allSatisfy { !$0.inGame }
    }
    
    private var hasRakeOrTips: Bool {
        session.rakeAmount > 0 || session.tipsAmount > 0
    }
    
    var body: some View {
        Group {
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
                        Text("Общий закуп фишек:")
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
                        Text("Фишки в игре:")
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
                        Text("Выведено фишек:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(session.totalCashOut)")
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
                
            }
        }
        Section {
            if allPlayersFinished && session.chipsInGame > 0 && !hasRakeOrTips {
                Button {
                    showingRakeSheet = true
                } label: {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Распределить остаток")
                        Spacer()
                        Text("\(session.chipsInGame) фишек")
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            if hasRakeOrTips {
                VStack {
                    HStack {
                        Text("Распределенный остаток фишек:")
                            .font(.caption)
                        Spacer()
                        Menu {
                            Button(role: .destructive) {
                                viewModel.clearRakeAndTips(for: session)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                                .imageScale(.large)
                                .padding(5)
                        }
                    }
                    Line()
                        .stroke(style: .init(dash: [1]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(height: 1)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            if session.rakeAmount > 0 {
                                HStack {
                                    Text("Рейк ->")
                                    Spacer()
                                    Text("\(session.rakeAmount) фишек")
                                }
                            }
                            
                            if session.tipsAmount > 0 {
                                HStack {
                                    Text("Чаевые ->")
                                    Spacer()
                                    Text("\(session.tipsAmount) фишек")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        
                    }
                }
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
    // 1) Сценарий: все игроки завершили, есть остаток, рейк/чаевые не записаны → кнопка "Распределить остатки"
    let sessionAwaiting = PreviewData.awaitingSettlementsSession()
    
    // 2) Сценарий: есть рейк и чаевые → показывается второй Section с управлением
    let sessionWithRake = PreviewData.activeSession()
    sessionWithRake.rakeAmount = 300
    sessionWithRake.tipsAmount = 200
    sessionWithRake.chipsToCashRatio = 2
    
    // 3) Сценарий: есть банк → строка "Банк сессии" отображает состояние банка
    let sessionWithBank = PreviewData.sessionWithBank()
    
    // 4) Сценарий: экстремально большие значения buy-in/cash-out
    let huge = Session(
        startTime: Date(),
        location: "High Stakes",
        gameType: .NLHoldem,
        status: .active,
        sessionTitle: "Миллиардные стеки"
    )
    huge.chipsToCashRatio = 1

    let p1 = Player(name: "Билл", inGame: true)
    p1.transactions = [
        PlayerChipTransaction(type: .chipBuyIn, amount: 1_000_000_000, player: p1),      // 1 млрд
        PlayerChipTransaction(type: .chipAddOn, amount: 500_000_000, player: p1)         // +0.5 млрд
    ]

    let p2 = Player(name: "Илон", inGame: false)
    p2.transactions = [
        PlayerChipTransaction(type: .chipBuyIn, amount: 2_000_000_000, player: p2),      // 2 млрд
        PlayerChipTransaction(type: .сhipCashOut, amount: 1_800_000_000, player: p2)     // вывел 1.8 млрд
    ]

    let p3 = Player(name: "Джефф", inGame: true)
    p3.transactions = [
        PlayerChipTransaction(type: .chipBuyIn, amount: 750_000_000, player: p3),        // 0.75 млрд
        PlayerChipTransaction(type: .chipAddOn, amount: 750_000_000, player: p3),        // +0.75 млрд
        PlayerChipTransaction(type: .сhipCashOut, amount: 100_000_000, player: p3)       // вывел 0.1 млрд
    ]

    huge.players = [p1, p2, p3]
    huge.rakeAmount = 50_000_000      // 50 млн фишек рейка
    huge.tipsAmount = 25_000_000      // 25 млн фишек чаевых

    return NavigationStack {
        List {
            Section("Есть рейк/чаевые — блок управления") {
                ChipsStatsSection(session: sessionWithRake, showingRakeSheet: .constant(false))
            }
            Section("Без рейка/чаевых, все завершили — кнопка распределения") {
                ChipsStatsSection(session: sessionAwaiting, showingRakeSheet: .constant(false))
            }
            Section("С банком") {
                ChipsStatsSection(session: sessionWithBank, showingRakeSheet: .constant(false))
            }
            Section("Экстремально большие значения") {
                ChipsStatsSection(session: huge, showingRakeSheet: .constant(false))
            }
        }
        .navigationTitle("Превью статистики банка")
    }
    .modelContainer(for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
    .environment(SessionDetailViewModel())
}
