import SwiftUI
import SwiftData

struct ClubMemberStatsView: View {
    @Environment(\.modelContext) private var context

    @Bindable var member: ClubMember
    @Query private var aggregates: [ClubMemberStats]

    @State private var sessionRows: [ClubMemberSessionStats] = []
    @State private var exportedFileURL: URL?
    @State private var showExportError = false
    @State private var exportError: Error?
    @State private var isExportInProgress = false
    @State private var exportProgress = 0.0
    @State private var exportProgressText = "Подготовка данных..."

    @State private var showDateFilterSheet = false
    @State private var appliedDateFilter: StatsDateFilter = .all
    @State private var draftPreset: StatsDateFilterPreset = .last30
    @State private var draftFromDate = Date().addingTimeInterval(-30 * 86_400)
    @State private var draftToDate = Date()

    private let exportService: PlayerStatsExportServiceProtocol = PlayerStatsExportService()

    init(member: ClubMember) {
        self.member = member
        let memberID = member.id
        _aggregates = Query(
            filter: #Predicate<ClubMemberStats> { $0.memberId == memberID }
        )
    }

    var body: some View {
        List {
            if !appliedDateFilter.isAll {
                Section("Период") {
                    HStack {
                        Text("Диапазон")
                        Spacer()
                        Text(filterDescription)
                            .foregroundStyle(.secondary)
                    }
                    Button("Сбросить фильтр") {
                        clearDateFilter()
                    }
                }
            }

            if snapshot.sessionsCount == 0 {
                ContentUnavailableView(
                    "Нет статистики",
                    systemImage: "chart.bar",
                    description: Text(emptyStateDescription)
                )
            } else {
                Section("Основные показатели") {
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
                        "Рейкбек получено",
                        value: snapshot.totalRakeback,
                        description: "Сумма рейкбека, начисленная участнику во всех кеш-сессиях клуба."
                    )
                    metricRow(
                        "Общий buy-in",
                        value: snapshot.totalBuyIn,
                        description: "Сумма всех входов участника в кеш-сессии клуба."
                    )
                    metricRow(
                        "Общий cash-out",
                        value: snapshot.totalCashOut,
                        description: "Сумма всех выводов участника из кеш-сессий клуба."
                    )
                    metricRow(
                        "ROI",
                        percent(snapshot.roi),
                        description: "Окупаемость: итоговый PnL, делённый на общий buy-in."
                    )
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    openDateFilterSheet()
                } label: {
                    Image(
                        systemName: appliedDateFilter.isAll
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                    )
                }
                .disabled(isExportInProgress)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportStatsReport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(snapshot.sessionsCount == 0 || isExportInProgress)
            }
        }
        .task(id: filterTaskID) {
            reloadSessionRows()
        }
        .sheet(isPresented: $showDateFilterSheet) {
            dateFilterSheet
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
            Text(exportError?.localizedDescription ?? "Не удалось экспортировать CSV")
        }
        .overlay {
            if isExportInProgress {
                exportProgressOverlay
            }
        }
    }

    private var emptyStateDescription: String {
        if appliedDateFilter.isAll {
            return "Добавьте игрока в кеш-сессию клуба, чтобы увидеть данные"
        }
        return "За выбранный период у участника нет кеш-сессий."
    }

    private var filterDescription: String {
        switch appliedDateFilter {
        case .all:
            return "За всё время"
        case .lastDays(let days, _):
            return "Последние \(days) дн."
        case .custom:
            guard let bounds = appliedDateFilter.bounds else { return "За всё время" }
            let from = bounds.from.formatted(.dateTime.day().month().year())
            let to = bounds.to.formatted(.dateTime.day().month().year())
            return "\(from) - \(to)"
        }
    }

    private var filterTaskID: String {
        switch appliedDateFilter {
        case .all:
            return "all"
        case .lastDays(let days, let referenceDate):
            let dayStart = Calendar.current.startOfDay(for: referenceDate)
            return "last-\(days)-\(dayStart.timeIntervalSince1970)"
        case .custom(let from, let to):
            let bounds = from <= to
                ? (from: from, to: to)
                : (from: to, to: from)
            return "custom-\(bounds.from.timeIntervalSince1970)-\(bounds.to.timeIntervalSince1970)"
        }
    }

    private var dateFilterSheet: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(StatsDateFilterPreset.quickPresets) { preset in
                        datePresetRow(preset)
                    }
                    datePresetRow(.custom)
                } header: {
                    Text("Быстрые периоды")
                } footer: {
                    Text("Выберите готовый период или укажите свой.")
                }

                if draftPreset == .custom {
                    Section {
                        DatePicker(
                            "С",
                            selection: $draftFromDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "По",
                            selection: $draftToDate,
                            in: draftFromDate...,
                            displayedComponents: .date
                        )
                    } header: {
                        Text("Свой период")
                    } footer: {
                        Text("Фильтр применяется только к кеш-сессиям выбранного участника.")
                    }
                }
            }
            .navigationTitle("Фильтр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showDateFilterSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        applyDateFilterFromDraft()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func datePresetRow(_ preset: StatsDateFilterPreset) -> some View {
        Button {
            draftPreset = preset
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                    if let subtitle = preset.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if draftPreset == preset {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("Формируем CSV")
                    .font(.headline)
                ProgressView(value: exportProgress, total: 1)
                    .progressViewStyle(.linear)
                HStack {
                    Text(exportProgressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((exportProgress * 100).rounded()))%")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 14)
            .padding(.horizontal, 20)
        }
        .transition(.opacity)
    }

    private func openDateFilterSheet() {
        switch appliedDateFilter {
        case .all:
            draftPreset = .all
            draftToDate = Date()
            draftFromDate = Date().addingTimeInterval(-30 * 86_400)
        case .lastDays(let days, _):
            draftPreset = StatsDateFilterPreset(days: days) ?? .custom
            if let bounds = appliedDateFilter.bounds {
                draftFromDate = bounds.from
                draftToDate = bounds.to
            }
        case .custom(let from, let to):
            draftPreset = .custom
            let bounds = from <= to
                ? (from: from, to: to)
                : (from: to, to: from)
            draftFromDate = bounds.from
            draftToDate = bounds.to
        }
        showDateFilterSheet = true
    }

    private func clearDateFilter() {
        appliedDateFilter = .all
    }

    private func applyDateFilterFromDraft() {
        switch draftPreset {
        case .all:
            appliedDateFilter = .all
        case .last7:
            appliedDateFilter = .lastDays(7, referenceDate: Date())
        case .last30:
            appliedDateFilter = .lastDays(30, referenceDate: Date())
        case .last90:
            appliedDateFilter = .lastDays(90, referenceDate: Date())
        case .custom:
            appliedDateFilter = .custom(from: draftFromDate, to: draftToDate)
        }
        showDateFilterSheet = false
    }

    private func reloadSessionRows() {
        let memberID = member.id
        let sort = [SortDescriptor(\ClubMemberSessionStats.sessionDate, order: .reverse)]
        let descriptor: FetchDescriptor<ClubMemberSessionStats>

        if let bounds = appliedDateFilter.bounds {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: bounds.from)
            let endStart = calendar.startOfDay(for: bounds.to)
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: endStart) ?? endStart

            descriptor = FetchDescriptor(
                predicate: #Predicate<ClubMemberSessionStats> {
                    $0.memberId == memberID &&
                    $0.sessionDate >= start &&
                    $0.sessionDate < endExclusive
                },
                sortBy: sort
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<ClubMemberSessionStats> { $0.memberId == memberID },
                sortBy: sort
            )
        }

        do {
            sessionRows = try context.fetch(descriptor)
        } catch {
            sessionRows = []
            assertionFailure("Failed to fetch filtered member session rows: \(error)")
        }
    }

    private func exportStatsReport() {
        guard snapshot.sessionsCount > 0, !isExportInProgress else { return }
        let report = makeReportData()

        isExportInProgress = true
        exportProgress = 0
        exportProgressText = "Подготовка данных..."

        exportService.exportReportOnMain(
            report,
            chunkSize: 200,
            onProgress: { progress in
                exportProgress = progress
                if progress < 0.98 {
                    exportProgressText = "Обработка сессий..."
                } else {
                    exportProgressText = "Сохранение файла..."
                }
            },
            completion: { result in
                isExportInProgress = false
                switch result {
                case .success(let url):
                    exportedFileURL = url
                case .failure(let error):
                    exportError = error
                    showExportError = true
                }
            }
        )
    }

    private func makeReportData() -> PlayerStatsExportReportData {
        let summaryMetrics: [PlayerStatsExportReportData.Metric] = [
            PlayerStatsExportReportData.Metric(
                title: "Сессий",
                value: "\(snapshot.sessionsCount)",
                description: "Количество сыгранных кеш-сессий в клубе."
            ),
            PlayerStatsExportReportData.Metric(
                title: "Винрейт",
                value: percent(snapshot.winRate),
                description: "Доля сессий, закрытых в плюс по реальному результату."
            ),
            PlayerStatsExportReportData.Metric(
                title: "Итоговый PnL",
                value: snapshot.totalRealPnL.asCurrency(showSign: true),
                description: "Результат с учетом рейкбека, банка и расходов."
            ),
            PlayerStatsExportReportData.Metric(
                title: "ROI",
                value: percent(snapshot.roi),
                description: "Окупаемость: итоговый PnL / общий buy-in."
            )
        ]

        let turnoverMetrics: [PlayerStatsExportReportData.Metric] = [
            PlayerStatsExportReportData.Metric(
                title: "Общий buy-in",
                value: snapshot.totalBuyIn.asCurrency(),
                description: "Сумма всех входов игрока в сессии клуба."
            ),
            PlayerStatsExportReportData.Metric(
                title: "Общий cash-out",
                value: snapshot.totalCashOut.asCurrency(),
                description: "Сумма всех выходов игрока из сессий клуба."
            ),
            PlayerStatsExportReportData.Metric(
                title: "Рейкбек",
                value: snapshot.totalRakeback.asCurrency(),
                description: "Сумма начисленного рейкбека по всем сессиям."
            )
        ]

        let rows = sessionRows.map {
            PlayerStatsExportReportData.SessionRow(
                title: $0.sessionTitle.nonEmptyTrimmed ?? "Без названия",
                date: $0.sessionDate,
                buyIn: $0.buyIn,
                cashOut: $0.cashOut,
                realPnL: $0.realPnL
            )
        }

        return PlayerStatsExportReportData(
            memberName: member.name,
            clubName: member.club.name,
            generatedAt: Date(),
            filterDescription: appliedDateFilter.isAll ? nil : filterDescription,
            summaryMetrics: summaryMetrics,
            turnoverMetrics: turnoverMetrics,
            sessions: rows
        )
    }

    private var snapshot: StatsSnapshot {
        if appliedDateFilter.isAll, let aggregate = aggregates.first {
            return StatsSnapshot(
                sessionsCount: aggregate.sessionsCount,
                winRate: aggregate.winRate,
                totalBuyIn: aggregate.totalBuyIn,
                totalCashOut: aggregate.totalCashOut,
                totalRealPnL: aggregate.totalRealPnL,
                totalRakeback: aggregate.totalRakeback,
                roi: aggregate.roi
            )
        }

        let sessionsCount = sessionRows.count
        let winCount = sessionRows.filter { $0.realPnL > 0 }.count
        let totalBuyIn = sessionRows.reduce(0) { $0 + $1.buyIn }
        let totalCashOut = sessionRows.reduce(0) { $0 + $1.cashOut }
        let totalRealPnL = sessionRows.reduce(0) { $0 + $1.realPnL }
        let totalRakeback = sessionRows.reduce(0) { $0 + $1.rakeback }

        let winRate = sessionsCount > 0 ? Double(winCount) / Double(sessionsCount) : 0
        let roi = totalBuyIn > 0 ? Double(totalRealPnL) / Double(totalBuyIn) : 0

        return StatsSnapshot(
            sessionsCount: sessionsCount,
            winRate: winRate,
            totalBuyIn: totalBuyIn,
            totalCashOut: totalCashOut,
            totalRealPnL: totalRealPnL,
            totalRakeback: totalRakeback,
            roi: roi
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

private enum StatsDateFilterPreset: String, CaseIterable, Identifiable {
    case all
    case last7
    case last30
    case last90
    case custom

    var id: Self { self }

    static var quickPresets: [StatsDateFilterPreset] {
        [.all, .last7, .last30, .last90]
    }

    var title: String {
        switch self {
        case .all:
            return "За всё время"
        case .last7:
            return "Последние 7 дней"
        case .last30:
            return "Последние 30 дней"
        case .last90:
            return "Последние 90 дней"
        case .custom:
            return "Свой период"
        }
    }

    var subtitle: String? {
        switch self {
        case .all:
            return "Показать полную статистику"
        case .last7:
            return "Короткий срез за неделю"
        case .last30:
            return "Стандартный срез за месяц"
        case .last90:
            return "Широкий срез за квартал"
        case .custom:
            return "Выберите даты вручную"
        }
    }

    init?(days: Int) {
        switch days {
        case 7:
            self = .last7
        case 30:
            self = .last30
        case 90:
            self = .last90
        default:
            return nil
        }
    }
}

private enum StatsDateFilter: Equatable {
    case all
    case lastDays(Int, referenceDate: Date)
    case custom(from: Date, to: Date)

    var isAll: Bool {
        if case .all = self { return true }
        return false
    }

    var bounds: (from: Date, to: Date)? {
        let calendar = Calendar.current
        switch self {
        case .all:
            return nil
        case .lastDays(let days, let referenceDate):
            let normalizedDays = max(days, 1)
            let end = referenceDate
            let endDayStart = calendar.startOfDay(for: end)
            let from = calendar.date(
                byAdding: .day,
                value: -(normalizedDays - 1),
                to: endDayStart
            ) ?? endDayStart
            return from <= end ? (from, end) : (end, from)
        case .custom(let from, let to):
            return from <= to ? (from, to) : (to, from)
        }
    }
}

private struct StatsSnapshot {
    let sessionsCount: Int
    let winRate: Double
    let totalBuyIn: Int
    let totalCashOut: Int
    let totalRealPnL: Int
    let totalRakeback: Int
    let roi: Double
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
        aggregate.totalBuyIn = 750_000
        aggregate.totalCashOut = 880_000
        aggregate.totalRealPnL = 128_000
        aggregate.totalRakeback = 32_000
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
                realPnL: 52_000,
                rakeback: 8_000
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 5),
                sessionTitle: "Ночной кэш",
                buyIn: 150_000,
                cashOut: 90_000,
                realPnL: -70_000,
                rakeback: 0
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 9),
                sessionTitle: "Субботний стол",
                buyIn: 200_000,
                cashOut: 260_000,
                realPnL: 73_000,
                rakeback: 13_000
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 14),
                sessionTitle: "Домашняя сессия",
                buyIn: 120_000,
                cashOut: 120_000,
                realPnL: -8_000,
                rakeback: 0
            ),
            ClubMemberSessionStats(
                sessionId: UUID(),
                memberId: member.id,
                clubId: club.id,
                sessionDate: now.addingTimeInterval(-86_400 * 20),
                sessionTitle: "Большой стол",
                buyIn: 180_000,
                cashOut: 250_000,
                realPnL: 81_000,
                rakeback: 11_000
            )
        ]
        rows.forEach(context.insert)

        return (container, member)
    }
}
