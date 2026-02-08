import SwiftUI
import SwiftData

struct TournamentSessionDetailView: View {
    @Bindable var session: Session
    @State private var selectedInfoTab: Int = 1
    @State private var destination: TournamentDestination?
    @Environment(SessionDetailViewModel.self) var viewModel

    private var navigationTitle: String {
        session.status.rawValue
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $selectedInfoTab) {
                    Text("Инфо").tag(0)
                    Text("Статус").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(5)

            if selectedInfoTab == 0 {
                tournamentInfoSection
            } else {
                tournamentStatusSection
            }

            navigationSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.automatic)
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .participants:
                TournamentParticipantsView(session: session)
            case .seating:
                TournamentTablesView(session: session)
            case .blindStructure:
                TournamentBlindStructureView(session: session)
            case .payoutStructure:
                TournamentPayoutStructureView(session: session)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    //TODO: сделать добавление игрока в турнир
                } label: {
                    Image(systemName: "person.badge.plus.fill")
                }
            }
        }
    }

    // MARK: - Tournament Info Section

    private var tournamentInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow(
                    label: "Сессия:",
                    value: session.displayTitle
                )

                divider

                HStack {
                    Text("Дата:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                    Text(session.startTime, format: .dateTime)
                        .font(.headline)
                        .fontDesign(.monospaced)
                }

                divider

                summaryRow(
                    label: "Игра:",
                    value: session.gameType.rawValue
                )

                divider

                summaryRow(
                    label: "Бай-ин:",
                    value: session.entryFee?.formatted() ?? "—"
                )
            }
            .italic()
            .fontDesign(.monospaced)
        }
    }


    private var tournamentStatusSection: some View {
        Section {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Участники:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("активные / всего")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.activePlayers.count)/\(session.players.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.brown)
                        .fontDesign(.monospaced)
                }

                TournamentLine()
                    .stroke(style: .init(dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: 1)

                VStack(spacing: 4) {
                    HStack {
                        Text("Всего входов:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(entriesCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                            .fontDesign(.monospaced)
                    }

                    HStack {
                        Text("Уникальных / Ре-энтри")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(session.players.count) / \(rebuysCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                    }
                }

                TournamentLine()
                    .stroke(style: .init(dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: 1)

                HStack {
                    Text("Призовой фонд:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(prizePoolDisplay)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .fontDesign(.monospaced)
                }
            }
            .italic()
            .fontDesign(.monospaced)
        }
    }

    private var navigationSection: some View {
        Section {
            VStack(spacing: 12) {
                Button {
                    destination = .participants
                } label: {
                    participantsNavigationCard()
                }
                .buttonStyle(.plain)

                Button {
                    destination = .seating
                } label: {
                    seatingNavigationCard()
                }
                .buttonStyle(.plain)

                Button {
                    destination = .blindStructure
                } label: {
                    blindStructureNavigationCard()
                }
                .buttonStyle(.plain)

                Button {
                    destination = .payoutStructure
                } label: {
                    payoutStructureNavigationCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func participantsNavigationCard() -> some View {
        let activeCount = session.activePlayers.count
        let totalCount = session.players.count

        return DashboardCard(backgroundColor: Color.teal.opacity(0.15)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.teal)
                        .font(.title2)
                    Text("Участники")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if totalCount > 0 {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        navigationMetricRow(
                            label: "Активные / всего",
                            value: "\(activeCount)/\(totalCount)",
                            color: .teal
                        )
                        navigationMetricRow(
                            label: "Входов / ре-энтри",
                            value: "\(entriesCount)/\(rebuysCount)",
                            color: .secondary
                        )
                    }
                } else {
                    Text("Нет участников")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func seatingNavigationCard() -> some View {
        DashboardCard(backgroundColor: Color.blue.opacity(0.15)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("Рассадка")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Divider()

                Text(seatingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func blindStructureNavigationCard() -> some View {
        DashboardCard(backgroundColor: Color.orange.opacity(0.15)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text("Структура блайндов")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    navigationMetricRow(
                        label: "Блайнды",
                        value: "\(session.smallBlind)/\(session.bigBlind)",
                        color: .orange
                    )
                    if session.ante > 0 {
                        navigationMetricRow(
                            label: "Анте",
                            value: "\(session.ante)",
                            color: .secondary
                        )
                    }
                }
            }
        }
    }

    private func payoutStructureNavigationCard() -> some View {
        DashboardCard(backgroundColor: Color.green.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("Структура выплат")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    navigationMetricRow(
                        label: "Призовой фонд",
                        value: prizePoolDisplay,
                        color: .green
                    )
                    navigationMetricRow(
                        label: "Участников",
                        value: "\(session.players.count)",
                        color: .secondary
                    )
                }
            }
        }
    }

    private var divider: some View {
        TournamentLine()
            .stroke(style: .init(dash: [5]))
            .foregroundStyle(.secondary.opacity(0.5))
            .frame(height: 1)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
            Spacer()
            Text(value)
                .font(.headline)
        }
    }

    private func navigationMetricRow(label: String, value: String, color: Color) -> some View {
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

    private var prizePoolDisplay: String {
        if let prizePool = session.prizePoolTotal {
            return prizePool.formatted()
        }
        if let entryFee = session.entryFee {
            return (entryFee * session.players.count).formatted()
        }
        return "—"
    }

    private var entriesCount: Int {
        let buyIns = session.players.reduce(0) { partial, player in
            partial + player.transactions.filter { $0.type == .chipBuyIn }.count
        }
        return buyIns > 0 ? buyIns : session.players.count
    }

    private var seatingStatusText: String {
        session.players.isEmpty ? "Добавьте участников для рассадки" : "Настройте столы для рассадки"
    }

    private var rebuysCount: Int {
        max(entriesCount - session.players.count, 0)
    }
}

// MARK: - Preview

private func tournamentDetailPreview(session: Session) -> some View {
    NavigationStack {
        TournamentSessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(PreviewData.previewContainer)
}

// MARK: - Placeholder Views (UI only)

private struct TournamentParticipantsView: View {
    @Bindable var session: Session

    var body: some View {
        List {
            if session.players.isEmpty {
                ContentUnavailableView(
                    "Нет участников",
                    systemImage: "person.3",
                    description: Text("Добавьте игроков для начала турнира")
                )
            } else {
                ForEach(session.players) { player in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.name)
                            Text(player.inGame ? "В игре" : "Выбыл")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Участники")
    }
}

private struct TournamentTablesView: View {
    @Bindable var session: Session

    var body: some View {
        List {
            ContentUnavailableView(
                "Нет столов",
                systemImage: "rectangle.grid.2x2",
                description: Text("Настройте столы для рассадки")
            )
        }
        .navigationTitle("Столы")
    }
}

private struct TournamentBlindStructureView: View {
    @Bindable var session: Session

    var body: some View {
        List {
            ContentUnavailableView(
                "Структура не задана",
                systemImage: "clock.badge",
                description: Text("Добавьте уровни блайндов")
            )
        }
        .navigationTitle("Структура блайндов")
    }
}

private struct TournamentPayoutStructureView: View {
    @Bindable var session: Session

    var body: some View {
        List {
            ContentUnavailableView(
                "Выплаты не заданы",
                systemImage: "trophy",
                description: Text("Добавьте структуру выплат")
            )
        }
        .navigationTitle("Структура выплат")
    }
}

private struct TournamentLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

private enum TournamentDestination: Identifiable {
    case participants
    case seating
    case blindStructure
    case payoutStructure

    var id: String {
        switch self {
        case .participants:
            return "participants"
        case .seating:
            return "seating"
        case .blindStructure:
            return "blindStructure"
        case .payoutStructure:
            return "payoutStructure"
        }
    }
}

#Preview("Активный турнир") {
    @Previewable @State var tournament = Session(
        startTime: Date(),
        location: "Покер клуб Центральный",
        gameType: .NLHoldem,
        sessionType: .tournament,
        status: .active,
        sessionTitle: "Friday Night Tournament"
    )
    tournament.entryFee = 5000
    tournament.startingStack = 10000
    tournament.allowReEntry = true
    tournament.smallBlind = 25
    tournament.bigBlind = 50
    tournament.ante = 5

    return tournamentDetailPreview(session: tournament)
}

#Preview("Пустой турнир") {
    @Previewable @State var tournament = Session(
        startTime: Date(),
        location: "Home Game",
        gameType: .PLO4,
        sessionType: .tournament,
        status: .active,
        sessionTitle: "PLO Tournament"
    )
    tournament.entryFee = 3000
    tournament.startingStack = 5000

    return tournamentDetailPreview(session: tournament)
}
