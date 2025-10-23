import SwiftUI
import SwiftData
import Observation

struct SessionDetailView: View {
    @Bindable var session: Session
    
    @State private var showAddPlayer = false
    @State private var showAddExpense = false
    @State private var showingBlindsSheet = false
    
    @Environment(SessionDetailViewModel.self) var viewModel
    
    var body: some View {
        List {
            SessionInfoSection(
                session: session,
                showingBlindsSheet: $showingBlindsSheet
            )
            
            BankStatsSection(session: session)
            
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
                        Label("Добавить расход", systemImage: "cart.fill.badge.plus")
                    }
                    
                    NavigationLink {
                        SessionBankView(session: session)
                            .environment(viewModel)
                    } label: {
                        Label("Банк сессии", systemImage: "building.columns")
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

    NavigationStack {
        SessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
}
