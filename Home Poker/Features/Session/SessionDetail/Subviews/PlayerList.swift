import SwiftUI
import SwiftData

struct PlayerList: View {
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var playerToDelete: Player?
    @State private var showDeleteAlert: Bool = false

    var activePlayers: [Player] {
        session.players.filter { $0.inGame }
    }

    var finishedPlayers: [Player] {
        session.players.filter { !$0.inGame }
    }

    var body: some View {
        Group {
            // Секция активных игроков
            if !activePlayers.isEmpty {
                Section {
                    ForEach(activePlayers, id: \.id) { player in
                        NavigationLink {
                            PlayerTransactionsView(player: player, session: session)
                        } label: {
                            PlayerRow(player: player, session: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                playerToDelete = player
                                showDeleteAlert.toggle()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Активные игроки (\(activePlayers.count))")
                            .foregroundStyle(.primary)
                            .animation(nil, value: activePlayers.count)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            // Секция завершивших игроков
            if !finishedPlayers.isEmpty {
                Section {
                    ForEach(finishedPlayers, id: \.id) { player in
                        NavigationLink {
                            PlayerTransactionsView(player: player, session: session)
                        } label: {
                            PlayerRow(player: player, session: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                playerToDelete = player
                                showDeleteAlert.toggle()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Завершившие игроки (\(finishedPlayers.count))")
                            .foregroundStyle(.secondary)
                            .animation(nil, value: finishedPlayers.count)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .alert("Удалить игрока \(playerToDelete?.name ?? "Нет выбран")?", isPresented: $showDeleteAlert) {
            Button(role: .destructive) {
                if let player = playerToDelete {
                    withAnimation {
                        viewModel.removePlayer(player, from: session)

                    }
                }
                playerToDelete = nil
            } label: {
                Text("Удалить")
                    .foregroundStyle(.red)
            }

            Button("Отмена", role: .cancel) {
                playerToDelete = nil
            }
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()

    return NavigationStack {
        List {
            PlayerList(session: session)
        }
    }
    .environment(SessionDetailViewModel())
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}
