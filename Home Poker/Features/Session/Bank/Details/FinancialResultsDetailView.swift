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
                HStack {
                    Text(player.name)
                        .font(.body)

                    Spacer()

                    Text(max(bank?.financialResult(for: player) ?? 0, 0).asCurrency())
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .monospaced()
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Суммы к получению")
        }
        
        footer: {
            HStack {
                Spacer()
                Text(totalProfit.asCurrency())
                    .monospaced()
            }
        }
    }

    private var playersInLossSection: some View {
        Section {
            ForEach(playersInLoss, id: \.id) { player in
                HStack {
                    Text(player.name)
                        .font(.body)

                    Spacer()

                    Text(max(-(bank?.financialResult(for: player) ?? 0), 0).asCurrency())
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .monospaced()
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Суммы к оплате")
        }
        
        footer: {
            HStack {
                Spacer()
                Text(totalLoss.asCurrency())
                    .monospaced()
            }
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
