import SwiftUI
import SwiftData

struct SessionBankView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var settlementVM: SettlementViewModel = SettlementViewModel()
    @State private var showingDepositSheet = false
    @State private var showingWithdrawalSheet = false
    @State private var showSettlementSheet = false
    @State private var transactionToDelete: SessionBankTransaction?
    @State private var showingDeleteConfirmation = false

    private var sortedPlayers: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var sortedEntries: [SessionBankTransaction] {
        session.bank?.transactions.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    private var allPlayersFinished: Bool {
        !session.players.isEmpty && session.players.allSatisfy { !$0.inGame }
    }
    
    private var canCalculateSettlement: Bool {
        guard session.bank != nil else { return false }

        // Можно рассчитаться если все игроки завершили игру
        // Settlement теперь корректно обрабатывает частичные взносы в банк
        return allPlayersFinished
    }

    // MARK: - Body

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
                depositButton
                withdrawalButton
                settlementButton
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
            "Удалить транзакцию?",
            isPresented: $showingDeleteConfirmation,
            presenting: transactionToDelete
        ) { transaction in
            Button("Отмена", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                _ = viewModel.deleteBankTransaction(transaction, from: session)
                transactionToDelete = nil
            }
        } message: { transaction in
            Text("Эта операция не может быть отменена.")
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
                color: .primary)
            
            // Показываем резервы если есть рейк или чаевые
            if bank.totalReserved > 0 {
                reservesView(bank: bank)
            }
        }
    }
    
    private func reservesView(bank: SessionBank) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Зарезервировано всего:")
                Spacer()
                Text(formatCurrency(bank.totalReserved))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            if bank.reservedForRake > 0 {
                reserveItemRow(title: "Рейк", amount: bank.reservedForRake)
            }

            if bank.reservedForTips > 0 {
                reserveItemRow(title: "Чаевые", amount: bank.reservedForTips)
            }
        }
    }

    private func reserveItemRow(title: String, amount: Int) -> some View {
        HStack {
            Text("• \(title)")
                .font(.caption2)
            Spacer()
            Text(formatCurrency(amount))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func debtorsSection(bank: SessionBank) -> some View {
        let debtors = bank.playersOwingBank
        let totalDebt = debtors.reduce(0) { $0 + bank.amountOwedToBank(for: $1) }

        return playerDebtSection(
            title: "Игроки должны:",
            players: debtors,
            totalAmount: totalDebt,
            emptyMessage: "Нет должников",
            amountColor: .red,
            amountProvider: { bank.amountOwedToBank(for: $0) }
        )
    }

    private func owedByBankSection(bank: SessionBank) -> some View {
        playerDebtSection(
            title: "Банк должен:",
            players: bank.playersOwedByBank,
            totalAmount: bank.totalOwedByBank,
            emptyMessage: "Банк никому не должен",
            amountColor: .blue,
            amountProvider: { bank.amountOwedByBank(for: $0) },
            showPlayerDetails: true
        )
    }

    private func playerDebtSection(
        title: String,
        players: [Player],
        totalAmount: Int,
        emptyMessage: String,
        amountColor: Color,
        amountProvider: @escaping (Player) -> Int,
        showPlayerDetails: Bool = false
    ) -> some View {
        Section {
            if players.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(players, id: \.id) { player in
                    HStack {
                        if showPlayerDetails {
                            VStack(alignment: .leading) {
                                Text(player.name)
                                if player.profit > 0 {
                                    Text("Выплата выигрыша")
                                        .font(.caption2)
                                } else {
                                    Text("Возврат переплаты")
                                        .font(.caption2)
                                }
                            }
                        } else {
                            Text(player.name)
                        }
                        Spacer()
                        Text(formatCurrency(amountProvider(player)))
                            .foregroundStyle(amountColor)
                            .fontWeight(.semibold)
                    }
                }
            }
        } header: {
            HStack {
                Text(title)
                Text(formatCurrency(totalAmount))
                    .foregroundStyle(amountColor)
            }
            .font(.caption)
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
                Text("Пока нет транзакций")
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(entries, id: \.id) { entry in
                    entryRow(entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = entry
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
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
    
    // MARK: - Toolbar Buttons
    
    private var depositButton: some View {
        Button {
            showingDepositSheet = true
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.green)
        }
        .disabled(sortedPlayers.isEmpty)
    }

    private var withdrawalButton: some View {
        Button {
            showingWithdrawalSheet = true
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
        }
        .disabled(sortedPlayers.isEmpty)
    }
    
    private var settlementButton: some View {
        Button {
            settlementVM.calculate(for: session)
            showSettlementSheet = true
        } label: {
            Image(systemName: "receipt")
        }
        .disabled(!canCalculateSettlement)
    }

}

private extension SessionBankTransactionType {
    var displayName: String {
        switch self {
        case .deposit:
            return "Игрок передал в банк"
        case .withdrawal:
            return "Банк передал игроку"
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

// MARK: - Preview Helper

private func bankPreview(session: Session) -> some View {
    NavigationStack {
        SessionBankView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}

#Preview("Стандартный банк") {
    bankPreview(session: PreviewData.sessionWithBank())
}

#Preview("Полный банк (все секции)") {
    bankPreview(session: PreviewData.sessionWithFullBank())
}
