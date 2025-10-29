import SwiftUI
import SwiftData

struct SessionBankView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var settlementVM: SettlementViewModel = SettlementViewModel()
    
    
    @State private var showingDepositSheet = false
    @State private var showingWithdrawalSheet = false
    @State private var showSettlementSheet = false
    
    
    private var sortedPlayers: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var sortedEntries: [SessionBankTransaction] {
        session.bank?.transactions.sorted { $0.createdAt > $1.createdAt } ?? []
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
                if !bank.playersOwedByBank.isEmpty {
                    owedByBankSection(bank: bank)
                }
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
                        .foregroundStyle(isBankClosed ? .green.opacity(0.5) :.green)
                }
                .disabled(isBankClosed || sortedPlayers.isEmpty)
                
                Button {
                    showingWithdrawalSheet = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(isBankClosed ? .orange.opacity(0.5) :.orange)
                }
                .disabled(isBankClosed || sortedPlayers.isEmpty)
                
                Button {
                    settlementVM.calculate(for: session)
                    showSettlementSheet = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(!canCalculateSettlement)
                
                Button {
                    if isBankClosed {
                        viewModel.reopenBank(for: session)
                    } else {
                        viewModel.closeBank(for: session)
                    }
                } label: {
                    Image(systemName: isBankClosed ? "lock.fill" : "lock.open.fill")
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))
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
            if bank.isClosed {
                HStack {
                    Text("Банк закрыт")
                    Image(systemName: "lock.fill")
                    Spacer()
                    if let closedAt = bank.closedAt {
                        Text(closedAt, style: .date)
                    }
                }
            }
            summaryRow(title: "Получено от игроков", value: formatCurrency(bank.totalDeposited), color: .green)
            summaryRow(title: "Выдано игрокам", value: formatCurrency(bank.totalWithdrawn), color: .orange)
            summaryRow(
                title: "Баланс банка",
                value: formatCurrency(bank.netBalance),
                color: bank.netBalance > 0 ? .green : (bank.netBalance < 0 ? .red : .secondary)
            )
            
            
            
            let totalDebt = bank.playersOwingBank.reduce(0) { $0 + bank.amountOwedToBank(for: $1) }
            if totalDebt > 0 {
                summaryRow(
                    title: "Должны банку",
                    value: formatCurrency(totalDebt),
                    color: .red
                )
            }

            if bank.totalOwedByBank > 0 {
                summaryRow(
                    title: "Банк должен",
                    value: formatCurrency(bank.totalOwedByBank),
                    color: .blue
                )
            }
        }
    }
    
    private func debtorsSection(bank: SessionBank) -> some View {
        let debtors = bank.playersOwingBank
        return Section("Должны банку") {
            if debtors.isEmpty {
                Text("Нет должников")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(debtors, id: \.id) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text(formatCurrency(bank.amountOwedToBank(for: player)))
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func owedByBankSection(bank: SessionBank) -> some View {
        let creditors = bank.playersOwedByBank
        return Section("Банк должен игрокам") {
            if creditors.isEmpty {
                Text("Банк никому не должен")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(creditors, id: \.id) { player in
                    HStack {
                        // Иконка для различия выигравших от переплативших
                        if player.profit > 0 {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }

                        Text(player.name)
                        Spacer()
                        Text(formatCurrency(bank.amountOwedByBank(for: player)))
                            .foregroundStyle(.blue)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private func managerSection(bank: SessionBank) -> some View {
        Section("Ответственный") {
            Picker("Игрок", selection: Binding(
                get: { bank.manager?.id },
                set: { newManagerId in
                    if let newManagerId {
                        let player = sortedPlayers.first { $0.id == newManagerId }
                        viewModel.setBankManager(player, for: session)
                    } else {
                        viewModel.setBankManager(nil, for: session)
                    }
                }
            )) {
                Text("Не назначен").tag(nil as UUID?)
                ForEach(sortedPlayers, id: \.id) { player in
                    Text(player.name).tag(player.id as UUID?)
                }
            }
        }
    }
    
    private func entriesSection(entries: [SessionBankTransaction]) -> some View {
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
    
    private func entryRow(_ entry: SessionBankTransaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.type.displayName)
                Image(systemName: entry.type.systemImage)
                Spacer()
                Text(entry.amount.asCurrency())
                    .fontWeight(.semibold)
            }
            .foregroundColor(entry.type == .deposit ? .green : .orange)

            HStack {
                Text(entry.player?.name ?? "Удалённый игрок")
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
    
    private func formatCurrency(_ value: Int) -> String { value.asCurrency() }
}

private extension SessionBankTransactionType {
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
    let session = PreviewData.sessionWithBank()

    return NavigationStack {
        SessionBankView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}
