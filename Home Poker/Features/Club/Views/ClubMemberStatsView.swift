    import SwiftUI
import SwiftData

struct ClubMemberStatsView: View {
    @Bindable var member: ClubMember
    @Query private var aggregates: [ClubMemberStats]
    @Query private var sessionRows: [ClubMemberSessionStats]
    @State private var exportedFileURL: URL?
    @State private var showExportError = false
    @State private var exportError: Error?

    private let pdfExportService: PlayerStatsPDFExportServiceProtocol = PlayerStatsPDFExportService()

    init(member: ClubMember) {
        self.member = member
        let memberID = member.id
        _aggregates = Query(
            filter: #Predicate<ClubMemberStats> { $0.memberId == memberID }
        )
        _sessionRows = Query(
            filter: #Predicate<ClubMemberSessionStats> { $0.memberId == memberID },
            sort: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
    }

    var body: some View {
        List {
            if snapshot.sessionsCount == 0 {
                ContentUnavailableView(
                    "Нет статистики",
                    systemImage: "chart.bar",
                    description: Text("Добавьте игрока в кеш-сессию клуба, чтобы увидеть данные")
                )
            } else {
                Section("Сводка") {
                    metricRow(
                        "Сессий",
                        "\(snapshot.sessionsCount)",
                        description: "Количество кеш-сессий, в которых участник сыграл в этом клубе."
                    )
                    metricRow(
                        "Винрейт",
                        percent(snapshot.winRate),
                        description: "Доля сессий, завершённых в плюс по реальному результату."
                    )
                    metricRow(
                        "Итоговый PnL",
                        value: snapshot.totalRealPnL,
                        description: "Суммарный финансовый результат с учётом всех корректировок.",
                        emphasize: true
                    )
                    metricRow(
                        "Покерный PnL",
                        value: snapshot.totalPokerPnL,
                        description: "Чистый результат только по фишкам: cash-out минус buy-in."
                    )
                    metricRow(
                        "Средний PnL за сессию",
                        value: Int(snapshot.averageRealPnL.rounded()),
                        description: "Средняя прибыль или убыток за одну сыгранную сессию."
                    )
                    metricRow(
                        "ROI",
                        percent(snapshot.roi),
                        description: "Окупаемость вложений: итоговый PnL, делённый на общий buy-in."
                    )
                    metricRow(
                        "Рейкбек получено",
                        value: snapshot.totalRakeback,
                        description: "Сумма рейкбека, начисленная участнику во всех сессиях клуба."
                    )
                    metricRow(
                        "Сессии с add-on",
                        percent(snapshot.addOnRate),
                        description: "Процент сессий, где участник делал add-on."
                    )
                }

                Section("Оборот") {
                    metricRow(
                        "Общий buy-in",
                        value: snapshot.totalBuyIn,
                        description: "Сумма всех входов участника во все сессии клуба."
                    )
                    metricRow(
                        "Общий cash-out",
                        value: snapshot.totalCashOut,
                        description: "Сумма всех выводов участника из сессий клуба."
                    )
                    metricRow(
                        "Лучшая сессия",
                        value: snapshot.bestSessionRealPnL,
                        description: "Максимальный реальный плюс за одну сессию."
                    )
                    metricRow(
                        "Худшая сессия",
                        value: snapshot.worstSessionRealPnL,
                        description: "Максимальный реальный минус за одну сессию."
                    )
                }

                Section("По сессиям") {
                    ForEach(Array(sessionRows.prefix(100))) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.sessionTitle.nonEmptyTrimmed ?? "Без названия")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(row.realPnL.asCurrency())
                                    .foregroundStyle(pnlColor(row.realPnL))
                            }
                            HStack {
                                Text(row.sessionDate, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Buy-in \(row.buyIn.asCurrency()) · Cash-out \(row.cashOut.asCurrency())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportStatsReport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(snapshot.sessionsCount == 0)
            }
        }
        .sheet(isPresented: .constant(exportedFileURL != nil)) {
            if let exportedFileURL {
                ActivityViewController(activityItems: [exportedFileURL]) {
                    self.exportedFileURL = nil
                }
            }
        }
        .alert("Ошибка экспорта", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError?.localizedDescription ?? "Не удалось экспортировать PDF")
        }
    }

    private func exportStatsReport() {
        guard snapshot.sessionsCount > 0 else { return }
        do {
            let report = makeReportData()
            exportedFileURL = try pdfExportService.exportReport(report)
        } catch {
            exportError = error
            showExportError = true
        }
    }

    private func makeReportData() -> PlayerStatsPDFReportData {
        let summaryMetrics: [PlayerStatsPDFReportData.Metric] = [
            PlayerStatsPDFReportData.Metric(
                title: "Сессий",
                value: "\(snapshot.sessionsCount)",
                description: "Количество сыгранных кеш-сессий в клубе.",
                tone: .accent
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Винрейт",
                value: percent(snapshot.winRate),
                description: "Доля сессий, закрытых в плюс по реальному результату.",
                tone: .accent
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Итоговый PnL",
                value: snapshot.totalRealPnL.asCurrency(showSign: true),
                description: "Результат с учетом рейкбека, банка и расходов.",
                tone: metricTone(for: snapshot.totalRealPnL)
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Покерный PnL",
                value: snapshot.totalPokerPnL.asCurrency(showSign: true),
                description: "Только игра: cash-out минус buy-in.",
                tone: metricTone(for: snapshot.totalPokerPnL)
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Средний PnL",
                value: Int(snapshot.averageRealPnL.rounded()).asCurrency(showSign: true),
                description: "Средний результат за одну сессию.",
                tone: metricTone(for: Int(snapshot.averageRealPnL.rounded()))
            ),
            PlayerStatsPDFReportData.Metric(
                title: "ROI",
                value: percent(snapshot.roi),
                description: "Окупаемость: итоговый PnL / общий buy-in.",
                tone: metricTone(for: snapshot.totalRealPnL)
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Рейкбек",
                value: snapshot.totalRakeback.asCurrency(),
                description: "Сумма начисленного рейкбека по всем сессиям.",
                tone: .accent
            ),
            PlayerStatsPDFReportData.Metric(
                title: "С add-on",
                value: percent(snapshot.addOnRate),
                description: "Процент сессий, где игрок делал add-on.",
                tone: .neutral
            )
        ]

        let turnoverMetrics: [PlayerStatsPDFReportData.Metric] = [
            PlayerStatsPDFReportData.Metric(
                title: "Общий buy-in",
                value: snapshot.totalBuyIn.asCurrency(),
                description: "Сумма всех входов игрока в сессии клуба.",
                tone: .neutral
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Общий cash-out",
                value: snapshot.totalCashOut.asCurrency(),
                description: "Сумма всех выходов игрока из сессий клуба.",
                tone: .neutral
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Лучшая сессия",
                value: snapshot.bestSessionRealPnL.asCurrency(showSign: true),
                description: "Максимальный плюс за одну сессию.",
                tone: metricTone(for: snapshot.bestSessionRealPnL)
            ),
            PlayerStatsPDFReportData.Metric(
                title: "Худшая сессия",
                value: snapshot.worstSessionRealPnL.asCurrency(showSign: true),
                description: "Максимальный минус за одну сессию.",
                tone: metricTone(for: snapshot.worstSessionRealPnL)
            )
        ]

        let rows = sessionRows.map {
            PlayerStatsPDFReportData.SessionRow(
                title: $0.sessionTitle.nonEmptyTrimmed ?? "Без названия",
                date: $0.sessionDate,
                buyIn: $0.buyIn,
                cashOut: $0.cashOut,
                realPnL: $0.realPnL
            )
        }

        return PlayerStatsPDFReportData(
            memberName: member.name,
            clubName: member.club.name,
            generatedAt: Date(),
            summaryMetrics: summaryMetrics,
            turnoverMetrics: turnoverMetrics,
            sessions: rows
        )
    }

    private func metricTone(for value: Int) -> PlayerStatsPDFReportData.MetricTone {
        if value > 0 { return .positive }
        if value < 0 { return .negative }
        return .neutral
    }

    private var snapshot: StatsSnapshot {
        if let aggregate = aggregates.first {
            return StatsSnapshot(
                sessionsCount: aggregate.sessionsCount,
                winRate: aggregate.winRate,
                addOnRate: aggregate.addOnRate,
                totalBuyIn: aggregate.totalBuyIn,
                totalCashOut: aggregate.totalCashOut,
                totalPokerPnL: aggregate.totalPokerPnL,
                totalRealPnL: aggregate.totalRealPnL,
                totalRakeback: aggregate.totalRakeback,
                averageRealPnL: aggregate.averageRealPnL,
                roi: aggregate.roi,
                bestSessionRealPnL: aggregate.bestSessionRealPnL,
                worstSessionRealPnL: aggregate.worstSessionRealPnL
            )
        }

        let sessionsCount = sessionRows.count
        let winCount = sessionRows.filter { $0.realPnL > 0 }.count
        let addOnCount = sessionRows.filter { $0.hasAddOn }.count
        let totalBuyIn = sessionRows.reduce(0) { $0 + $1.buyIn }
        let totalCashOut = sessionRows.reduce(0) { $0 + $1.cashOut }
        let totalPokerPnL = sessionRows.reduce(0) { $0 + $1.pokerPnL }
        let totalRealPnL = sessionRows.reduce(0) { $0 + $1.realPnL }
        let totalRakeback = sessionRows.reduce(0) { $0 + $1.rakeback }
        let best = sessionRows.map(\.realPnL).max() ?? 0
        let worst = sessionRows.map(\.realPnL).min() ?? 0

        let winRate = sessionsCount > 0 ? Double(winCount) / Double(sessionsCount) : 0
        let addOnRate = sessionsCount > 0 ? Double(addOnCount) / Double(sessionsCount) : 0
        let average = sessionsCount > 0 ? Double(totalRealPnL) / Double(sessionsCount) : 0
        let roi = totalBuyIn > 0 ? Double(totalRealPnL) / Double(totalBuyIn) : 0

        return StatsSnapshot(
            sessionsCount: sessionsCount,
            winRate: winRate,
            addOnRate: addOnRate,
            totalBuyIn: totalBuyIn,
            totalCashOut: totalCashOut,
            totalPokerPnL: totalPokerPnL,
            totalRealPnL: totalRealPnL,
            totalRakeback: totalRakeback,
            averageRealPnL: average,
            roi: roi,
            bestSessionRealPnL: best,
            worstSessionRealPnL: worst
        )
    }

    @ViewBuilder
    private func metricRow(_ title: String, _ value: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func metricRow(
        _ title: String,
        value: Int,
        description: String,
        emphasize: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value.asCurrency())
                    .foregroundStyle(emphasize ? pnlColor(value) : .secondary)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> String {
        let formatted = (value * 100).formatted(.number.precision(.fractionLength(1)))
        return "\(formatted)%"
    }

    private func pnlColor(_ value: Int) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

private struct StatsSnapshot {
    let sessionsCount: Int
    let winRate: Double
    let addOnRate: Double
    let totalBuyIn: Int
    let totalCashOut: Int
    let totalPokerPnL: Int
    let totalRealPnL: Int
    let totalRakeback: Int
    let averageRealPnL: Double
    let roi: Double
    let bestSessionRealPnL: Int
    let worstSessionRealPnL: Int
}

#Preview("Заполненная статистика") {
    let preview = ClubMemberStatsPreviewData.make()

    return NavigationStack {
        ClubMemberStatsView(member: preview.member)
    }
    .modelContainer(preview.container)
}

private enum ClubMemberStatsPreviewData {
    @MainActor
    static func make() -> (container: ModelContainer, member: ClubMember) {
        let schema = Schema([
            Club.self,
            ClubMember.self,
            ClubMemberStats.self,
            ClubMemberSessionStats.self,
            Session.self,
            Player.self,
            PlayerChipTransaction.self,
            Expense.self,
            SessionBank.self,
            SessionBankTransaction.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let club = Club(name: "Everland Poker")
        let member = ClubMember(name: "Мария", club: club)
        club.members = [member]
        context.insert(club)

        let aggregate = ClubMemberStats(memberId: member.id, clubId: club.id)
        aggregate.sessionsCount = 5
        aggregate.winSessionsCount = 3
        aggregate.addOnSessionsCount = 2
        aggregate.totalBuyIn = 750_000
        aggregate.totalCashOut = 880_000
        aggregate.totalPokerPnL = 130_000
        aggregate.totalRealPnL = 128_000
        aggregate.totalRakeback = 32_000
        aggregate.bestSessionRealPnL = 81_000
        aggregate.worstSessionRealPnL = -70_000
        aggregate.updatedAt = Date()
        context.insert(aggregate)

        let now = Date()
        let rows: [ClubMemberSessionStats] = [
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 1),
                sessionTitle: "Пятничная игра",
                buyIn: 100_000,
                cashOut: 160_000,
                pokerPnL: 60_000,
                realPnL: 52_000,
                rakeback: 8_000,
                hasAddOn: false
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 5),
                sessionTitle: "Ночной кэш",
                buyIn: 150_000,
                cashOut: 90_000,
                pokerPnL: -60_000,
                realPnL: -70_000,
                rakeback: 0,
                hasAddOn: true
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 9),
                sessionTitle: "Субботний стол",
                buyIn: 200_000,
                cashOut: 260_000,
                pokerPnL: 60_000,
                realPnL: 73_000,
                rakeback: 13_000,
                hasAddOn: false
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 14),
                sessionTitle: "Домашняя сессия",
                buyIn: 120_000,
                cashOut: 120_000,
                pokerPnL: 0,
                realPnL: -8_000,
                rakeback: 0,
                hasAddOn: false
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 20),
                sessionTitle: "Большой стол",
                buyIn: 180_000,
                cashOut: 250_000,
                pokerPnL: 70_000,
                realPnL: 81_000,
                rakeback: 11_000,
                hasAddOn: true
            )
        ]
        rows.forEach(context.insert)

        return (container, member)
    }
}
