//
//  BankSummaryDetailView.swift
//  Home Poker
//
//  Детальный экран итогов банка: баланс, транзакции, долги
//  Содержит функционал депозитов и withdrawals
//

import SwiftUI
import SwiftData

struct BankSummaryDetailView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var showingDepositSheet = false
    @State private var showingWithdrawalSheet = false
    @State private var transactionToDelete: SessionBankTransaction?

    private var sortedPlayers: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var sortedTransactions: [SessionBankTransaction] {
        session.bank?.transactions.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    var body: some View {
        List {
            if let bank = session.bank {
                summarySection(bank: bank)

                if !bank.playersOwingBank.isEmpty {
                    debtorsSection(bank: bank)
                }

                if !bank.playersOwedByBank.isEmpty {
                    owedByBankSection(bank: bank)
                }

                transactionsSection
            } else {
                ContentUnavailableView("Банк не создан", systemImage: "banknote")
                    .onAppear {
                        viewModel.ensureBank(for: session)
                    }
            }
        }
        .navigationTitle("Касса")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                depositButton
                withdrawalButton
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
        .alert(
            "Удалить транзакцию?",
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            ),
            presenting: transactionToDelete
        ) { transaction in
            Button("Отмена", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                _ = viewModel.deleteBankTransaction(transaction, from: session)
                transactionToDelete = nil
            }
        } message: { _ in
            Text("Эта операция не может быть отменена.")
        }
    }

    // MARK: - Sections

    private func summarySection(bank: SessionBank) -> some View {
        Section("Итоги") {
            summaryRow(
                title: "Получено от игроков",
                value: bank.totalDeposited.asCurrency(),
                color: .green
            )
            summaryRow(
                title: "Выдано игрокам",
                value: bank.totalWithdrawn.asCurrency(),
                color: .orange
            )
            summaryRow(
                title: "Баланс кассы",
                value: bank.netBalance.asCurrency(),
                color: bank.netBalance >= 0 ? .primary : .red,
                isHighlighted: true
            )
        }
    }

    private func debtorsSection(bank: SessionBank) -> some View {
        let debtors = bank.playersOwingBank
        let totalDebt = debtors.reduce(0) { $0 + bank.amountOwedToBank(for: $1) }

        return Section {
            ForEach(debtors, id: \.id) { player in
                HStack {
                    Text(player.name)
                    Spacer()
                    Text(bank.amountOwedToBank(for: player).asCurrency())
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                        .monospaced()
                }
            }
        } header: {
            HStack {
                Text("Игроки должны банку")
                Spacer()
                Text(totalDebt.asCurrency())
                    .foregroundStyle(.red)
                    .monospaced()
            }
            .font(.caption)
        }
    }

    private func owedByBankSection(bank: SessionBank) -> some View {
        let creditors = bank.playersOwedByBank
        let totalOwed = bank.totalOwedByBank

        return Section {
            ForEach(creditors, id: \.id) { player in
                HStack {
                    VStack(alignment: .leading) {
                        Text(player.name)
                        if player.chipProfit > 0 {
                            Text("Выплата выигрыша")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Возврат переплаты")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(bank.amountOwedByBank(for: player).asCurrency())
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                        .monospaced()
                }
            }
        } header: {
            HStack {
                Text("Банк должен игрокам")
                Spacer()
                Text(totalOwed.asCurrency())
                    .foregroundStyle(.blue)
                    .monospaced()
            }
            .font(.caption)
        }
    }

    private var transactionsSection: some View {
        Section("Транзакции (\(sortedTransactions.count))") {
            if sortedTransactions.isEmpty {
                Text("Пока нет транзакций")
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(sortedTransactions, id: \.id) { transaction in
                    transactionRow(transaction)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = transaction
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Row Components

    private func summaryRow(
        title: String,
        value: String,
        color: Color,
        isHighlighted: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(isHighlighted ? .body.weight(.semibold) : .body)
            Spacer()
            Text(value)
                .font(isHighlighted ? .body.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(color)
                .monospaced()
        }
    }

    private func transactionRow(_ transaction: SessionBankTransaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.type.displayName)
                Image(systemName: transaction.type.systemImage)
                Spacer()
                Text(transaction.amount.asCurrency())
                    .fontWeight(.semibold)
                    .monospaced()
            }
            .foregroundColor(transaction.type == .deposit ? .green : .orange)

            HStack {
                Text(transaction.player?.name ?? "Удалённый игрок")
                Spacer()
                Text(transaction.createdAt, style: .time)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

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
}

// MARK: - Extensions

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

// MARK: - Previews

#Preview("Standard Bank") {
    NavigationStack {
        BankSummaryDetailView(session: PreviewData.sessionWithBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}

#Preview("Full Bank") {
    NavigationStack {
        BankSummaryDetailView(session: PreviewData.sessionWithFullBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}
