import SwiftUI

struct PlayersSectionView: View {
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var playerToDelete: Player?
    @State private var showDeleteAlert = false
    
    var body: some View {
        Section {
            ForEach(session.players, id: \.id) { player in
                NavigationLink {
                    PlayerTransactionsView(player: player)
                } label: {
                    PlayerRow(player: player, session: session)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        playerToDelete = player
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Text("Игроки (\(session.players.count))")
                Spacer()
                // Text("Активных: \(activeCount)")
                .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .alert("Удалить игрока?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) {
                if let player = playerToDelete {
                    viewModel.removePlayer(player, from: session)
                }
                playerToDelete = nil
                showDeleteAlert = false
            }
            Button("Отмена", role: .cancel) {
                playerToDelete = nil
                showDeleteAlert = false
            }
        } message: {
            Text("Все транзакции и данные игрока будут удалены из сессии.")
        }
    }
}
