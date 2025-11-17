//
//  RakeReservesDetailView.swift
//  Home Poker
//
//  Детальный экран рейка и резервов
//  Содержит информацию о зарезервированных средствах и функционал рейкбека
//

import SwiftUI
import SwiftData

struct RakeReservesDetailView: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var showingRakebackSheet = false

    private var distributedRakeback: Int {
        session.players.filter { $0.getsRakeback }.reduce(0) { $0 + $1.rakeback }
    }

    private var canDistributeRakeback: Bool {
        viewModel.availableRakebackAmount(for: session) > 0
    }

    var body: some View {
        List {
            if let bank = session.bank {
                if bank.totalReserved > 0 {
                    reservedSummarySection(bank: bank)

                    if bank.reservedForRake > 0 {
                        rakeSection(bank: bank)
                    }

                    if bank.reservedForTips > 0 {
                        tipsSection(bank: bank)
                    }
                } else {
                    ContentUnavailableView(
                        "Нет зарезервированных средств",
                        systemImage: "banknote",
                        description: Text("Рейк и чаевые не установлены для этой сессии")
                    )
                }
            } else {
                ContentUnavailableView("Банк не создан", systemImage: "banknote")
                    .onAppear {
                        viewModel.ensureBank(for: session)
                    }
            }
        }
        .navigationTitle("Рейк и резервы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                distributeRakebackButton
            }
        }
        .sheet(isPresented: $showingRakebackSheet) {
            NavigationStack {
                RakebackDistributionView(session: session)
                    .environment(viewModel)
            }
        }
    }

    // MARK: - Секции

    private func reservedSummarySection(bank: SessionBank) -> some View {
        Section {
            HStack {
                Text("Сумма:")
                    .font(.body.weight(.semibold))
                Spacer()
                Text(bank.totalReserved.asCurrency())
                    .font(.body.weight(.bold))
                    .monospaced()
            }
        }
    }

    private func rakeSection(bank: SessionBank) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.orange)
                        .font(.title3)

                    Text("Рейка собрано:")
                        .font(.headline)
                    Spacer()
                    Text(bank.reservedForRake.asCurrency())
                        .font(.body.weight(.bold))
                        .foregroundStyle(.orange)
                        .monospaced()

                    
                }

                if distributedRakeback > 0 || bank.reservedForRake > 0 {
                    Divider()
                    if distributedRakeback > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Распределено рейкбеком")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(distributedRakeback.asCurrency())
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.green)
                                .monospaced()


                            // Список игроков с рейкбеком
                            let playersWithRakeback = session.players.filter { $0.getsRakeback && $0.rakeback > 0 }
                            if !playersWithRakeback.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(playersWithRakeback, id: \.id) { player in
                                        Text("\(player.name): \(player.rakeback.asCurrency())")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospaced()

                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        Line()
                            .stroke(style: .init(dash: [5]))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .frame(height: 1)
                    }

                    // Расходы, оплаченные из рейка
                    if bank.totalExpensesPaidFromRake > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Оплачено расходов")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(bank.totalExpensesPaidFromRake.asCurrency())
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.orange)
                                .monospaced()
                        }
                        Line()
                            .stroke(style: .init(dash: [5]))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .frame(height: 1)
                    }

                    // Доступный рейк = рейк минус распределенный рейкбек минус оплаченные расходы
                    let availableRake = bank.availableRakeForExpenses
                    if availableRake > 0 {

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Доступно")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(availableRake.asCurrency())
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)
                                .monospaced()

                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Рейк")
        }
        footer: {
            if canDistributeRakeback {
                Text("Вы можете распределить рейкбек между игроками")
            }
        }
    }

    private func tipsSection(bank: SessionBank) -> some View {
        Section {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text("Чаевые дилеру:")
                    .font(.headline)
                Spacer()
                Text(bank.reservedForTips.asCurrency())
                    .font(.body.weight(.bold))
                    .foregroundStyle(.blue)
                    .monospaced()

            }
            .padding(.vertical, 4)
        } header: {
            Text("Чаевые")
        } footer: {
            Text("Сумма зарезервирована для чаевых дилеру")
        }
    }

    // MARK: - Кнопки тулбара

    private var distributeRakebackButton: some View {
        Button {
            showingRakebackSheet = true
        } label: {
            HStack {
                Image(systemName:"arrow.triangle.2.circlepath")
                Text("Рейкбек")
            }
        }
//        .disabled(!canDistributeRakeback)
    }
}

#Preview("With Rake and Tips") {
    NavigationStack {
        RakeReservesDetailView(session: PreviewData.sessionWithFullBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self],
        inMemory: true
    )
}

#Preview("No Reserves") {
    NavigationStack {
        RakeReservesDetailView(session: PreviewData.sessionWithBank())
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, SessionBank.self],
        inMemory: true
    )
}
