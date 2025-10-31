import SwiftUI
import SwiftData
import Observation
import TipKit

struct SessionDetailView: View {
    @Bindable var session: Session
    @State private var activeSheet: SheetType?
    @State private var selectedInfoTab: Int = 1
    @Environment(SessionDetailViewModel.self) var viewModel
    
    private let addPlayerTip = AddPlayerTip()
    
    enum SheetType: Identifiable {
        case addPlayer
        case addExpense
        case editSessionInfo
        case editBlinds
        case editRake
        
        var id: Self { self }
    }
    private var navigationTitle: String {
        session.status == .active ? "Активная сессия" : "Завершенная сессия"
    }
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        List {
            Section {
                Picker("", selection: $selectedInfoTab) {
                    Text("Инфо").tag(0)
                    Text("Фишки").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(5)
            
            
            // Условное отображение секций
            if selectedInfoTab == 0 {
                SessionInfoSummary(session: session) {
                    activeSheet = .editSessionInfo
                }
            } else {
                ChipsStatsSection(
                    session: session,
                    showingRakeSheet: Binding(
                        get: { activeSheet == .editRake },
                        set: { if $0 { activeSheet = .editRake } else { activeSheet = nil } }
                    )
                )
            }
            
            if !session.players.isEmpty {
                PlayerList(session: session)
            }
            
            TipView(addPlayerTip, arrowEdge: .bottom)
            
            
            Button {
                activeSheet = .addPlayer
                addPlayerTip.invalidate(reason: .actionPerformed)
            } label: {
                Label("Добавить игрока", systemImage: "person.badge.plus")
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.automatic)
        .sheet(item: $activeSheet) { sheetType in
            sheetContent(for: sheetType)
        }
        
        // MARK: - Toolbar
        
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
                        activeSheet = .addPlayer
                    } label: {
                        Label("Добавить игрока", systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        activeSheet = .addExpense
                    } label: {
                        Label("Добавить расход", systemImage: "cart.fill.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Ошибка", isPresented: $bindableViewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bindableViewModel.alertMessage ?? "")
        }
    }
    
    // MARK: - Sheet Content
    
    @ViewBuilder
    private func sheetContent(for type: SheetType) -> some View {
        switch type {
        case .addPlayer:
            AddPlayerSheet(session: session)
        case .addExpense:
            AddExpenseSheet(session: session)
        case .editSessionInfo:
            EditSessionInfoSheet(session: session)
        case .editBlinds:
            BlindsEditorSheet(session: session)
        case .editRake:
            RakeAndTipsSheet(session: session)
        }
    }
}

// MARK: - Preview

private func sessionDetailPreview(session: Session) -> some View {
    NavigationStack {
        SessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
    .task {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        Tips.showAllTipsForTesting()
    }
}

#Preview("Активная сессия") {
    sessionDetailPreview(session: PreviewData.activeSession())
}

#Preview("Завершенная сессия") {
    sessionDetailPreview(session: PreviewData.finishedSession())
}
