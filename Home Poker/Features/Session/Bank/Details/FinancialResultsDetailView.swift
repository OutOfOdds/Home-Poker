//
//  FinancialResultsDetailView.swift
//  Home Poker
//
//  Детальный экран финансовых результатов
//  Показывает игроков в плюсе и в минусе
//

import SwiftUI
import SwiftData

struct FinancialResultsDetailView: View {
    @Bindable var session: Session

    private var bank: SessionBank? {
        session.bank
    }

    // Игроки в плюсе (банк должен им)
    private var playersInProfit: [Player] {
        bank?.playersOwedByBank ?? []
    }

    // Игроки в минусе (они должны банку)
    private var playersInLoss: [Player] {
        bank?.playersOwingBank ?? []
    }

    // Общая сумма в плюсе
    private var totalProfit: Int {
        playersInProfit.reduce(0) { total, player in
            total + max(bank?.financialResult(for: player) ?? 0, 0)
        }
    }

    // Общая сумма в минусе
    private var totalLoss: Int {
        playersInLoss.reduce(0) { total, player in
            total + max(-(bank?.financialResult(for: player) ?? 0), 0)
        }
    }

    var body: some View {
        List {
            if bank != nil {

                
                // Игроки в плюсе
                if !playersInProfit.isEmpty {
                    playersInProfitSection
                }

                // Игроки в минусе
                if !playersInLoss.isEmpty {
                    playersInLossSection
                }

                // Empty state если все ещё в игре
                if playersInProfit.isEmpty && playersInLoss.isEmpty {
                    ContentUnavailableView(
                        "Нет финансовых результатов",
                        systemImage: "chart.bar",
                        description: Text("Финансовые результаты появятся после завершения игры игроками")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Банк не создан",
                    systemImage: "banknote"
                )
            }
        }
        .navigationTitle("Результаты игроков")
    }

    // MARK: - Секции

    private var summarySection: some View {
        Section("Итоги") {
            if !playersInProfit.isEmpty {
                HStack {
                    Text("Всего к получению")
                    Spacer()
                    Text(totalProfit.asCurrency())
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .monospaced()
                }
            }

            if !playersInLoss.isEmpty {
                HStack {
                    Text("Всего к оплате")
                    Spacer()
                    Text(totalLoss.asCurrency())
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .monospaced()
                }
            }
        }
    }

    private var playersInProfitSection: some View {
        Section {
            ForEach(playersInProfit, id: \.id) { player in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(player.name)
                            .font(.body)

                        Spacer()

                        Text(max(bank?.financialResult(for: player) ?? 0, 0).asCurrency())
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .monospaced()
                    }

                    // Breakdown компонентов
                    if let bank = bank {
                        breakdownView(for: player, bank: bank)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Суммы к получению")
        }

        footer: {
            HStack {
                Text("Итого к получению:")
                Spacer()
                Text(totalProfit.asCurrency())
            }
            .font(.caption2)
            .monospaced()
        }
    }

    private var playersInLossSection: some View {
        Section {
            ForEach(playersInLoss, id: \.id) { player in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(player.name)
                            .font(.body)

                        Spacer()

                        Text(max(-(bank?.financialResult(for: player) ?? 0), 0).asCurrency())
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                            .monospaced()
                        
                    }

                    // Breakdown компонентов
                    if let bank = bank {
                        breakdownView(for: player, bank: bank)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Суммы к оплате")
        }

        footer: {
            HStack {
                Text("Итого к оплате:")
                Spacer()
                Text(totalLoss.asCurrency())
            }
            .font(.caption2)
            .monospaced()
        }
    }

    // MARK: - Breakdown View

    @ViewBuilder
    private func breakdownView(for player: Player, bank: SessionBank) -> some View {
        VStack(alignment: .trailing) {
            // Покер (без рейкбека)
            let profit = player.chipCashOut - player.chipBuyIn
            let profitInCash = profit * session.chipsToCashRatio

            if profitInCash != 0 {
                breakdownRow(label: "Покер", amount: profitInCash)
            }

            // Рейкбек (если есть)
            let rakebackAdjustment = player.getsRakeback ? player.rakeback : 0
            if rakebackAdjustment > 0 {
                breakdownRow(label: "Рейкбек", amount: rakebackAdjustment)
            }

            // Банк
            let (deposited, withdrawn) = bank.contributions(for: player)
            let netContribution = deposited - withdrawn

            if netContribution != 0 {
                breakdownRow(label: "Банк", amount: netContribution)
            }

            // Расходы
            let expensePaid = session.expenses
                .filter { $0.payer?.id == player.id }
                .reduce(0) { $0 + $1.amount }

            let expenseShare = session.expenses
                .flatMap { $0.distributions }
                .filter { $0.player.id == player.id }
                .reduce(0) { $0 + $1.amount }

            let expenseAdjustment = expensePaid - expenseShare

            if expenseAdjustment != 0 {
                breakdownRow(label: "Расходы", amount: expenseAdjustment)
            }
        }

    }

    @ViewBuilder
    private func breakdownRow(label: String, amount: Int) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amount.asCurrency(showSign: true))
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("With Results") {
    NavigationStack {
        FinancialResultsDetailView(session: PreviewData.sessionWithFullBank())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self],
        inMemory: true
    )
}

#Preview("No Results") {
    NavigationStack {
        FinancialResultsDetailView(session: PreviewData.sessionWithBank())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self],
        inMemory: true
    )
}
