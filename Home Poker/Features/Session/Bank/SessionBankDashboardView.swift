//
//  SessionBankDashboardView.swift
//  Home Poker
//
//  Dashboard-стиль для банка сессии с карточками
//

import SwiftUI
import SwiftData

struct SessionBankDashboardView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var settlementVM: SettlementViewModel = SettlementViewModel()

    // State management для sheet
    @State private var activeSheet: BankSheet?

    private var sortedPlayers: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var allPlayersFinished: Bool {
        !session.players.isEmpty && session.players.allSatisfy { !$0.inGame }
    }

    private var canCalculateSettlement: Bool {
        guard session.bank != nil else { return false }
        return allPlayersFinished
    }

    var body: some View {
        Group {
            if let bank = session.bank {
                ScrollView {
                    VStack(spacing: 16) {
                        // 3 больших навигационных линка
                        navigationLinksSection(bank: bank)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Банк не создан", systemImage: "banknote")
                    .onAppear {
                        viewModel.ensureBank(for: session)
                    }
            }
        }
        .navigationTitle("Банк сессии")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                settlementButton
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func navigationLinksSection(bank: SessionBank) -> some View {
        VStack(spacing: 12) {
            // 2. Финансовый результат (фиолетовый) - игроки в плюсе/минусе
            NavigationLink {
                FinancialResultsDetailView(session: session)
            } label: {
                financialResultsNavigationCard(bank: bank)
            }
            .buttonStyle(.plain)
            
            
            // 1. Итоги банка (зелёный) - баланс, транзакции
            NavigationLink {
                BankSummaryDetailView(session: session)
                    .environment(viewModel)
            } label: {
                bankSummaryNavigationCard(bank: bank)
            }
            .buttonStyle(.plain)

     

            // 3. Рейк и резервы (оранжевый) - рейк, чаевые, рейкбек
            NavigationLink {
                RakeReservesDetailView(session: session)
                    .environment(viewModel)
            } label: {
                rakeReservesNavigationCard(bank: bank)
            }
            .buttonStyle(.plain)

            // 4. Расходы (синий) - список расходов, добавление
            NavigationLink {
                ExpensesDetailView(session: session)
                    .environment(viewModel)
            } label: {
                expensesNavigationCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Navigation Cards

    private func bankSummaryNavigationCard(bank: SessionBank) -> some View {
        DashboardCard(backgroundColor: Color.green.opacity(0.1)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "banknote")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("Касса")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    summaryMetricRow(
                        label: "Получено",
                        value: bank.totalDeposited.asCurrency(),
                        color: .green
                    )
                    summaryMetricRow(
                        label: "Выдано",
                        value: bank.totalWithdrawn.asCurrency(),
                        color: .orange
                    )
                    summaryMetricRow(
                        label: "Баланс",
                        value: bank.netBalance.asCurrency(),
                        color: bank.netBalance >= 0 ? .primary : .red
                    )
                }

            }
        }
    }

    private func financialResultsNavigationCard(bank: SessionBank) -> some View {
        let playersInProfit = bank.playersOwedByBank
        let playersInLoss = bank.playersOwingBank
        let totalProfit = playersInProfit.reduce(0) { $0 + max(bank.financialResult(for: $1), 0) }
        let totalLoss = playersInLoss.reduce(0) { $0 + max(-bank.financialResult(for: $1), 0) }

        return DashboardCard(backgroundColor: Color.purple.opacity(0.15)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.purple)
                        .font(.title2)
                    Text("Результаты игроков")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if !playersInProfit.isEmpty || !playersInLoss.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        if !playersInProfit.isEmpty {
                            summaryMetricRow(
                                label: "К получению (\(playersInProfit.count))",
                                value: totalProfit.asCurrency(),
                                color: .green
                            )
                        }

                        if !playersInLoss.isEmpty {
                            summaryMetricRow(
                                label: "К оплате (\(playersInLoss.count))",
                                value: totalLoss.asCurrency(),
                                color: .red
                            )
                        }
                    }
                } else {
                    Text("Нет финансовых результатов")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rakeReservesNavigationCard(bank: SessionBank) -> some View {
        let distributedRakeback = session.players.filter { $0.getsRakeback }.reduce(0) { $0 + $1.rakeback }

        return DashboardCard(backgroundColor: Color.orange.opacity(0.2)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "percent")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text("Рейк и резервы")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if bank.totalReserved > 0 {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        summaryMetricRow(
                            label: "Всего зарезервировано",
                            value: bank.totalReserved.asCurrency(),
                            color: .orange
                        )

                        if bank.reservedForRake > 0 {
                            summaryMetricRow(
                                label: "Рейк",
                                value: bank.reservedForRake.asCurrency(),
                                color: .secondary
                            )
                        }

                        if distributedRakeback > 0 {
                            summaryMetricRow(
                                label: "Рейкбек выдан",
                                value: distributedRakeback.asCurrency(),
                                color: .green
                            )
                        }
                    }
                } else {
                    Text("Нет резервов")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func expensesNavigationCard() -> some View {
        let totalExpenses = session.expenses.reduce(0) { $0 + $1.amount }
        let expenseCount = session.expenses.count

        return DashboardCard(backgroundColor: Color.blue.opacity(0.2)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cart")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("Расходы")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if expenseCount > 0 {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        summaryMetricRow(
                            label: "Всего расходов",
                            value: totalExpenses.asCurrency(),
                            color: .blue
                        )
                        summaryMetricRow(
                            label: "Количество",
                            value: "\(expenseCount)",
                            color: .secondary
                        )
                    }
                } else {
                    Text("Нет расходов")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summaryMetricRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .monospaced()
        }
    }

    // MARK: - Toolbar Buttons

    private var settlementButton: some View {
        Button {
            settlementVM.calculate(for: session)
            activeSheet = .settlement
        } label: {
            Image(systemName: "receipt")
        }
        .disabled(!canCalculateSettlement)
    }

    // MARK: - Sheet Management

    @ViewBuilder
    private func sheetContent(for sheet: BankSheet) -> some View {
        switch sheet {
        case .settlement:
            SettlementView(viewModel: settlementVM)
        }
    }
}

// MARK: - BankSheet Enum

enum BankSheet: Identifiable {
    case settlement

    var id: Self { self }
}

// MARK: - Previews

#Preview("Standard Bank") {
    NavigationStack {
        SessionBankDashboardView(session: PreviewData.sessionWithBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, ExpenseDistribution.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}

#Preview("Full Bank") {
    NavigationStack {
        SessionBankDashboardView(session: PreviewData.sessionWithFullBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, ExpenseDistribution.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}
