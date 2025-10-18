import SwiftUI
import SwiftData
import Observation

struct SessionDetailView: View {
    @Bindable var session: Session
    
    @State private var showAddPlayer = false
    @State private var showAddExpense = false
    @State private var showingBlindsSheet = false
    @State private var showSettlementSheet = false
    
    @State private var settlementVM: SettlementViewModel = SettlementViewModel()
    @Environment(SessionDetailViewModel.self) var viewModel
    
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
        }
        .navigationTitle(session.status == .active ? "Активная сессия" : "Завершенная сессия")
        .navigationBarTitleDisplayMode(.large)
        
        // MARK: Sheets
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerSheet(session: session)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(session: session)
        }
        .sheet(isPresented: $showingBlindsSheet) {
            BlindsEditorSheet(session: session)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettlementSheet) {
            SettlementView(viewModel: settlementVM)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Label("Добавить игрока", systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        showAddExpense = true
                    } label: {
                        Label("Добавить расходы", systemImage: "cart.fill.badge.plus")
                    }
                    
                    Divider()
                    
                    Button {
                        settlementVM.calculate(for: session)
                        showSettlementSheet = true
                    } label: {
                        Label("Рассчитать переводы", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!allPlayersFinished)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.clearAlert() } }
            ),
            presenting: viewModel.alertMessage
        ) { _ in
            Button("OK", role: .cancel) {
                viewModel.clearAlert()
            }
        } message: { message in
            Text(message)
        }
    }
}

// MARK: - Helpers
private extension SessionDetailView {
    var allPlayersFinished: Bool {
        // Кнопка доступна только если есть игроки и все они не в игре
        !session.players.isEmpty && session.players.allSatisfy { !$0.inGame }
    }
    
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

#Preview {
    // Тестовая сессия с 9 игроками (сумма результатов = 0)
    let session = Session(
        startTime: Date().addingTimeInterval(-60 * 60 * 3),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem, status: .active
    )
    
    // Создаем игроков и транзакции (buy-in / cash-out) вместо прямых свойств
    let p1 = Player(name: "Илья", inGame: true)
    p1.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p1),
        PlayerTransaction(type: .cashOut, amount: 3500, player: p1) // +1500
    ])
    
    let p2 = Player(name: "Андрей", inGame: false)
    p2.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p2),
        PlayerTransaction(type: .cashOut, amount: 1500, player: p2) // -1500
    ])
    
    let p3 = Player(name: "Сергей", inGame: true)
    p3.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p3),
        PlayerTransaction(type: .cashOut, amount: 2200, player: p3) // +200
    ])
    
    let p4 = Player(name: "Дмитрий", inGame: false)
    p4.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2500, player: p4),
        PlayerTransaction(type: .cashOut, amount: 1800, player: p4) // -700
    ])
    
    let p5 = Player(name: "Алексей", inGame: true)
    p5.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 1500, player: p5),
        PlayerTransaction(type: .cashOut, amount: 2100, player: p5) // +600
    ])
    
    let p6 = Player(name: "Павел", inGame: false)
    p6.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p6),
        PlayerTransaction(type: .cashOut, amount: 2600, player: p6) // -400
    ])
    
    let p7 = Player(name: "Роман", inGame: true)
    p7.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 1000, player: p7),
        PlayerTransaction(type: .cashOut, amount: 1300, player: p7) // +300
    ])
    
    let p8 = Player(name: "Виктор", inGame: true)
    p8.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 1800, player: p8),
        PlayerTransaction(type: .cashOut, amount: 1400, player: p8) // -400
    ])
    
    let p9 = Player(name: "Никита", inGame: true)
    p9.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2200, player: p9),
        PlayerTransaction(type: .cashOut, amount: 2600, player: p9) // +400
    ])
    
    session.players = [p1, p2, p3, p4, p5, p6, p7, p8, p9]
    
    // Пример расходов
    let e1 = Expense(amount: 800, note: "Напитки", createdAt: Date().addingTimeInterval(-3600), payer: p1)
    let e2 = Expense(amount: 1200, note: "Закуски", createdAt: Date().addingTimeInterval(-1800), payer: p2)
    session.expenses = [e1, e2]
    
    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self], inMemory: true)
}
