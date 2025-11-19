import SwiftUI
import SwiftData

struct TournamentSessionDetailView: View {
    @Bindable var session: Session
    @State private var selectedTab: Int = 0
    @Environment(SessionDetailViewModel.self) var viewModel

    private var navigationTitle: String {
        session.status.rawValue
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $selectedTab) {
                    Text("Инфо").tag(0)
                    Text("Игроки").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(5)

            if selectedTab == 0 {
                tournamentInfoSection
            } else {
                if !session.players.isEmpty {
                    PlayerList(session: session)
                } else {
                    ContentUnavailableView(
                        "Нет игроков",
                        systemImage: "person.3",
                        description: Text("Добавьте игроков для начала турнира")
                    )
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            ToolbarItem {
                Button {
                    // TODO: Add player action
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
    }

    // MARK: - Tournament Info Section

    private var tournamentInfoSection: some View {
        Group {
            SessionInfoSummary(session: session) {
                // TODO: Edit session info
            }

            Section("Параметры турнира") {
                LabeledContent("Бай-ин", value: session.entryFee?.formatted() ?? "—")
                LabeledContent("Стартовый стек", value: session.startingStack?.formatted() ?? "—")
                LabeledContent("Re-entry", value: session.allowReEntry ? "Разрешён" : "Не разрешён")

                if let prizePool = session.prizePoolTotal {
                    LabeledContent("Призовой фонд", value: prizePool.formatted())
                }
            }

            Section("Блайнды") {
                LabeledContent("Small Blind", value: "\(session.smallBlind)")
                LabeledContent("Big Blind", value: "\(session.bigBlind)")
                if session.ante > 0 {
                    LabeledContent("Ante", value: "\(session.ante)")
                }
            }
        }
    }
}

// MARK: - Preview

private func tournamentDetailPreview(session: Session) -> some View {
    NavigationStack {
        TournamentSessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self],
        inMemory: true
    )
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
