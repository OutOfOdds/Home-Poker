import SwiftUI
import SwiftData

struct SessionBankView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    @State private var showingDepositSheet = false
    @State private var showingWithdrawalSheet = false
    @State private var showSettlementSheet = false
    @State private var settlementVM: SettlementViewModel = SettlementViewModel()
    
    private var sortedPlayers: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var sortedEntries: [SessionBankEntry] {
        session.bank?.entries.sorted { $0.createdAt > $1.createdAt } ?? []
    }
    
    private var isBankClosed: Bool {
        session.bank?.isClosed ?? false
    }
    
    private var allPlayersFinished: Bool {
        !session.players.isEmpty && session.players.allSatisfy { !$0.inGame }
    }
    
    private var canCalculateSettlement: Bool {
        guard let bank = session.bank else { return false }
        return bank.isClosed && bank.remainingToCollect == 0 && allPlayersFinished
    }
    
    var body: some View {
        List {
            if let bank = session.bank {
                managerSection(bank: bank)
                summarySection(bank: bank)
                debtorsSection(bank: bank)
                entriesSection(entries: sortedEntries)
            } else {
                ContentUnavailableView("Банк не создан", systemImage: "banknote")
                    .onAppear {
                        viewModel.ensureBank(for: session)
                    }
            }
        }
        .navigationTitle("Банк сессии")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingDepositSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                }
                .disabled(isBankClosed || sortedPlayers.isEmpty)
                
                Button {
                    showingWithdrawalSheet = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
                .disabled(isBankClosed || sortedPlayers.isEmpty)
                
                Button {
                    settlementVM.calculate(for: session)
                    showSettlementSheet = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(!canCalculateSettlement)
                
                if isBankClosed {
                    Button("Открыть") {
                        viewModel.reopenBank(for: session)
                    }
                } else {
                    Button("Закрыть") {
                        if !viewModel.closeBank(for: session) {
                            // Ошибка покажется через alert viewModel
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDepositSheet) {
            SessionBankTransactionSheet(
                session: session,
                mode: .deposit
            )
        }
        .sheet(isPresented: $showingWithdrawalSheet) {
            SessionBankTransactionSheet(
                session: session,
                mode: .withdrawal
            )
        }
        .sheet(isPresented: $showSettlementSheet) {
            SettlementView(viewModel: settlementVM)
        }
        .onAppear {
            viewModel.ensureBank(for: session)
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
    
    private func summarySection(bank: SessionBank) -> some View {
        Section("Итоги") {
            summaryRow(title: "Ожидается", value: formatCurrency(bank.expectedTotal))
            summaryRow(title: "Получено", value: formatCurrency(bank.totalDeposited), color: .green)
            summaryRow(title: "Выдано", value: formatCurrency(bank.totalWithdrawn), color: .orange)
            summaryRow(
                title: "Осталось собрать",
                value: formatCurrency(bank.remainingToCollect),
                color: bank.remainingToCollect == 0 ? .secondary : .red
            )
            if bank.isClosed {
                HStack {
                    Label("Банк закрыт", systemImage: "lock.fill")
                    Spacer()
                    if let closedAt = bank.closedAt {
                        Text(closedAt, style: .date)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private func debtorsSection(bank: SessionBank) -> some View {
        let debtors = bank.debtors
        return Section("Должники") {
            if debtors.isEmpty {
                Text("Все расчёты закрыты")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(debtors, id: \.id) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text(formatCurrency(bank.outstandingAmount(for: player)))
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private func managerSection(bank: SessionBank) -> some View {
        Section("Ответственный") {
            Menu {
                Button("Не назначен") {
                    viewModel.setBankManager(nil, for: session)
                }
                Divider()
                ForEach(sortedPlayers, id: \.id) { player in
                    Button(player.name) {
                        viewModel.setBankManager(player, for: session)
                    }
                }
            } label: {
                HStack {
                    Text("Игрок")
                    Spacer()
                    Text(bank.manager?.name ?? "Не назначен")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func entriesSection(entries: [SessionBankEntry]) -> some View {
        Section("Транзакции (\(entries.count))") {
            if entries.isEmpty {
                Text("Пока нет движений")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.id) { entry in
                    entryRow(entry)
                }
            }
        }
    }
    
    private func entryRow(_ entry: SessionBankEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.type.displayName)
                Image(systemName: entry.type.systemImage)
                Spacer()
                Text("₽\(entry.amount)")
                    .fontWeight(.semibold)
            }
            .foregroundColor(entry.type == .deposit ? .green : .orange)

            HStack {
                Text(entry.player.name)
                Spacer()
                Text(entry.createdAt, style: .time)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func summaryRow(title: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(color)
        }
    }
    
    private func formatCurrency(_ value: Int) -> String {
        "₽\(value)"
    }
}

private extension SessionBankEntryType {
    var displayName: String {
        switch self {
        case .deposit:
            return "Взнос"
        case .withdrawal:
            return "Выплата"
        }
    }
    
    var systemImage: String {
        switch self {
        case .deposit:
            return "arrow.down.circle"
        case .withdrawal:
            return "arrow.up.circle"
        }
    }
}

#Preview {
    let session = Session(
        startTime: Date(),
        location: "Preview Spot",
        gameType: .NLHoldem,
        status: .active
    )
    
    let p1 = Player(name: "Илья", inGame: false)
    let p2 = Player(name: "Андрей", inGame: false)
    let p3 = Player(name: "Сергей", inGame: false)
    session.players = [p1, p2, p3]
    
    p1.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p1),
        PlayerTransaction(type: .cashOut, amount: 2000, player: p1)
    ])
    p2.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p2),
        PlayerTransaction(type: .cashOut, amount: 3000, player: p2)
    ])
    p3.transactions.append(
        PlayerTransaction(type: .buyIn, amount: 1500, player: p3)
    )
    
    let bank = SessionBank(session: session, manager: p1)
    bank.expectedTotal = session.players
        .filter { !$0.inGame }
        .reduce(0) { $0 + max($1.buyIn - $1.cashOut, 0) }
    session.bank = bank
    
    let entry1 = SessionBankEntry(amount: 1000, type: .deposit, player: p1, bank: bank, note: "Возврат")
    let entry2 = SessionBankEntry(amount: 1000, type: .deposit, player: p3, bank: bank, note: "Часть долга")
    let entry3 = SessionBankEntry(amount: 3000, type: .withdrawal, player: p2, bank: bank, note: "Выигрыш")
    bank.entries = [entry1, entry2, entry3]
    
    return NavigationStack {
        SessionBankView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
        inMemory: true
    )
}
