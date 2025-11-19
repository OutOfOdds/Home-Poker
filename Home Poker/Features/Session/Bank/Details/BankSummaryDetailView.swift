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
                title: "Получено:",
                value: bank.totalDeposited.asCurrency(),
                color: .green
            )
            summaryRow(
                title: "Выдано:",
                value: bank.totalWithdrawn.asCurrency(),
                color: .orange
            )
            summaryRow(
                title: "Баланс кассы:",
                value: bank.netBalance.asCurrency(),
                color: bank.netBalance >= 0 ? .primary : .red,
                isHighlighted: true
            )
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

    // MARK: - Строки статов

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
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "banknote")
                    Image(systemName: transaction.type.systemImage)
                    Text(transaction.type.displayName)
                }

            }
            .foregroundColor(transaction.type == .deposit ? .green : .orange)

            HStack {
                // Для организационных транзакций не показываем имя игрока
                if transaction.type == .deposit || transaction.type == .withdrawal {
                    Text(transaction.player?.name ?? "Удалённый игрок")
                }
                Spacer()
                Text(transaction.createdAt, style: .time)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Text(transaction.amount.asCurrency())
                .fontWeight(.semibold)
                .monospaced()
                .foregroundColor(transaction.type == .deposit ? .green : .orange)

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
    }

    private var withdrawalButton: some View {
        Button {
            showingWithdrawalSheet = true
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

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
