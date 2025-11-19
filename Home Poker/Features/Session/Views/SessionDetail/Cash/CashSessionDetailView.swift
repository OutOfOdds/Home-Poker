import SwiftUI
import SwiftData
import Observation
import TipKit

struct CashSessionDetailView: View {
    @Bindable var session: Session
    @State private var activeSheet: SheetType?
    @State private var selectedInfoTab: Int = 1
    @Environment(SessionDetailViewModel.self) var viewModel

    private let addPlayerTip = AddPlayerTip()
    private let bankTip = SessionBankTip()
    enum SheetType: Identifiable {
        case addPlayer
        case addExpense
        case editSessionInfo
        case editBlinds
        case editRake

        var id: Self { self }
    }
    private var navigationTitle: String {
        session.status.rawValue
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
                ChipsStatsView(
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
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.automatic)
        .sheet(item: $activeSheet) { sheetType in
            sheetContent(for: sheetType)
        }

        // MARK: - Toolbar

        .toolbar {
            ToolbarItem {
                NavigationLink {
                    SessionBankDashboardView(session: session)
                        .environment(viewModel)
                } label: {
                    HStack {
                        Image(systemName: "building.columns")
                        Text("Банк сессии")
                    }
                }
                .popoverTip(bankTip, arrowEdge: .top)
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }

            ToolbarItem {
                Button {
                    activeSheet = .addPlayer
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .popoverTip(addPlayerTip, arrowEdge: .top)
            }
        }
        .alert("Ошибка", isPresented: $bindableViewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bindableViewModel.alertMessage ?? "")
        }
        .onChange(of: session.players.count) { oldValue, newValue in
            if oldValue == 0 && newValue > 0 {
                SessionBankTip.hasAddedFirstPlayer = true
            }
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

private func cashSessionDetailPreview(session: Session) -> some View {
    NavigationStack {
        CashSessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
    .task {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        Tips.showAllTipsForTesting()
    }
}

#Preview("Активная сессия") {
    cashSessionDetailPreview(session: PreviewData.activeSession())
}

#Preview("Пустая сессия с TipKit") {
    cashSessionDetailPreview(session: PreviewData.emptySession())
}

#Preview("Завершенная сессия") {
    cashSessionDetailPreview(session: PreviewData.finishedSession())
}
