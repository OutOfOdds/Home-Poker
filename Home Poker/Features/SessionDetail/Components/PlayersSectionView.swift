import SwiftUI

struct PlayersSectionView: View {
    let session: Session

    var body: some View {
        Section {
            ForEach(session.players, id: \.id) { player in
                NavigationLink {
                    PlayerTransactionsView(player: player)
                } label: {
                    PlayerRow(player: player, session: session)
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
    }
}
