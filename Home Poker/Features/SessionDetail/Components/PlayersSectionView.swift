import SwiftUI

struct PlayersSectionView: View {
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @State private var pendingDeletion: DeletionTarget?

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
                        pendingDeletion = DeletionTarget(player: player)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Text("Игроки (\(session.players.count))")
                Spacer()
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .alert(item: $pendingDeletion) { target in
            Alert(
                title: Text("Удалить игрока?"),
                message: Text("Все транзакции и данные игрока будут удалены из сессии."),
                primaryButton: .destructive(Text("Удалить")) {
                    viewModel.removePlayer(target.player, from: session)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct DeletionTarget: Identifiable {
    let id = UUID()
    let player: Player
}
