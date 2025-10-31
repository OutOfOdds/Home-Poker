import SwiftUI
import SwiftData
import Observation

struct SessionDetailView: View {
    @Bindable var session: Session
    
    @State private var showAddPlayer = false
    @State private var showAddExpense = false
    @State private var showingBlindsSheet = false
    @State private var showingRakeSheet = false

    @Environment(SessionDetailViewModel.self) var viewModel
    
    var body: some View {
        List {
            SessionInfoSection(session: session,showingBlindsSheet: $showingBlindsSheet)
            
            ChipsStatsSection(session: session, showingRakeSheet: $showingRakeSheet)
            
            if !session.players.isEmpty {
                PlayerList(session: session)
            }
            
            Button {
                showAddPlayer = true
            } label: {
                Label("Добавить игрока", systemImage: "person.badge.plus")
            }
        }
        .navigationTitle(session.status == .active ? "Активная сессия" : "Завершенная сессия")
        .navigationBarTitleDisplayMode(.large)
        
        // MARK: Sheets
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingBlindsSheet) {
            BlindsEditorSheet(session: session)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingRakeSheet) {
            RakeAndTipsSheet(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SessionBankView(session: session)
                        .environment(viewModel)
                } label: {
                    HStack {
                        Image(systemName: "building.columns")
                        Text("Банк сессии")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Label("Добавить игрока", systemImage: "person.badge.plus")
                    }

                    Button {
                        showAddExpense = true
                    } label: {
                        Label("Добавить расход", systemImage: "cart.fill.badge.plus")
                    }
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

#Preview {
    let session = PreviewData.activeSession()
    
    if #available(iOS 26.0, *) {
        TabView {
            NavigationStack {
                SessionDetailView(session: session)
                    .environment(SessionDetailViewModel())
                 
            }
            .tabItem {
                Label("Сессия", systemImage: "clock")
            }
            
            // Для наглядности можно добавить вторую вкладку
            Text("Другое")
                .tabItem {
                    Label("Другое", systemImage: "square.grid.2x2")
                }
        }
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
    } else {
        // Fallback on earlier versions
    }
}
