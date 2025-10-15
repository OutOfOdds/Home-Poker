import SwiftUI
import SwiftData
import Observation

struct SessionDetailView: View {
    @Bindable var session: Session
    
    @State private var showAddPlayer = false
    @State private var showAddExpense = false
    @State private var showingBlindsSheet = false
    @State private var showSettlementSheet = false
    
    var body: some View {
        List {
            SessionInfoSectionView(
                session: session,
                showingBlindsSheet: $showingBlindsSheet
            )
            
            BankStatsSectionView(session: session)
            
            if !session.players.isEmpty {
                PlayersSectionView(session: session)
            }
            
            addPlayerSection
                .listSectionSpacing(.custom(8))
            
            addExpenseSection
                .listSectionSpacing(.custom(8))
            
            Section {
                Button {
                    showSettlementSheet = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Рассчитать переводы")
                    }
                }
            }
        }
        .navigationTitle(session.status == .active ? "Активная сессия" : "Завершенная сессия")
        .navigationBarTitleDisplayMode(.large)
        
        // MARK: Sheets
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerView(session: session)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(session: session)
        }
        .sheet(isPresented: $showingBlindsSheet) {
            BlindsEditorView(session: session)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettlementSheet) {
            SettlementView(session: session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sections
private extension SessionDetailView {
    var addPlayerSection: some View {
        Section {
            Button {
                showAddPlayer = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Добавить игрока")
                }
            }
        }
    }
    
    var addExpenseSection: some View {
        Section {
            Button {
                showAddExpense = true
            } label: {
                HStack {
                    Image(systemName: "cart.fill.badge.plus")
                    Text("Добавить расходы")
                }
            }
        }
    }
}

// MARK: - Helpers
private extension SessionDetailView {
    func blindsDisplayText() -> String {
        if session.smallBlind == 0 && session.bigBlind == 0 && session.ante == 0 {
            return "Нажмите для указания"
        }
        var base = "\(formatCurrency(session.smallBlind))/\(formatCurrency(session.bigBlind))"
        if session.ante > 0 {
            base += " (Анте: \(formatCurrency(session.ante)))"
        }
        return base
    }
    
    func formatCurrency(_ amount: Int) -> String {
        "₽\(amount)"
    }
}

//#Preview {
//    // Тестовая сессия с 9 игроками (сумма результатов = 0)
//    let session = Session(
//        startTime: Date().addingTimeInterval(-60 * 60 * 3),
//        location: "Клуб «Флоп»",
//        gameType: .NLHoldem, status: .active
//    )
//    
//    let p1 = Player(name: "Илья", isActive: true, buyIn: 2000);  p1.cashOut = 3500   // +1500
//    let p2 = Player(name: "Андрей", isActive: false, buyIn: 3000); p2.cashOut = 1500 // -1500
//    let p3 = Player(name: "Сергей", isActive: true, buyIn: 2000);  p3.cashOut = 2200  // +200
//    let p4 = Player(name: "Дмитрий", isActive: false, buyIn: 2500); p4.cashOut = 1800 // -700
//    let p5 = Player(name: "Алексей", isActive: true, buyIn: 1500); p5.cashOut = 2100  // +600
//    let p6 = Player(name: "Павел", isActive: false, buyIn: 3000);  p6.cashOut = 2600  // -400
//    let p7 = Player(name: "Роман", isActive: true, buyIn: 1000);   p7.cashOut = 1300   // +300
//    let p8 = Player(name: "Виктор", isActive: true, buyIn: 1800);  p8.cashOut = 1400   // -400
//    let p9 = Player(name: "Никита", isActive: true, buyIn: 2200);  p9.cashOut = 2600   // +400
//    
//    session.players = [p1, p2, p3, p4, p5, p6, p7, p8, p9]
//    
//    // Пример расходов
//    let e1 = Expense(amount: 800, note: "Напитки", createdAt: Date().addingTimeInterval(-3600), payer: p1)
//    let e2 = Expense(amount: 1200, note: "Закуски", createdAt: Date().addingTimeInterval(-1800), payer: p2)
//    session.expenses = [e1, e2]
//    
//    NavigationStack {
//        SessionDetailView(session: session)
//    }
//    .modelContainer(for: [Session.self, Player.self, Expense.self], inMemory: true)
//}
