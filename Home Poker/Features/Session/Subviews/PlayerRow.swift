import SwiftUI

struct PlayerRow: View {
    var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    @State private var showingBuyInSheet = false
    @State private var showingCashOutSheet = false
    @State private var showingRebuySheet = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    
                    HStack {
                        Text(player.name)
                            .font(.headline)
                            .opacity(player.inGame ? 1 : 0.5)
                        if !player.inGame {
                            Text("(завершил)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !player.inGame {
                        HStack {
                            Text("\(player.profit >= 0 ? "+" : "")\(player.profit)")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.dynamicColor(value: player.profit))
                                .fontDesign(.monospaced)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Закуплено фишек: \(player.buyIn)")
                        if !player.inGame {
                            Text("Выведено фишек: \(player.cashOut)")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .italic()
                    .fontDesign(.monospaced)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if player.inGame {
                HStack {
                    Button {
                        showingBuyInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Докупка")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    
                    Button {
                        showingCashOutSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "figure.walk.departure")
                            Text("Завершить")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    Button {
                        showingRebuySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.left")
                            Text("Вернуть в игру")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Spacer()

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
        }
        .sheet(isPresented: $showingBuyInSheet) {
            PlayerAddOnSheet(player: player, session: session)
        }
        .sheet(isPresented: $showingCashOutSheet) {
            PlayerCashOutSheet(player: player, session: session)
        }
        .sheet(isPresented: $showingRebuySheet) {
            RebuyPlayerSheet(player: player, session: session)
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        return amount.asCurrency()
    }
    
    private var displayedProfitColor: Color {
        if player.profit == 0 {
            return .secondary
        }
        return player.profit > 0 ? .green : .red
    }
    
    private var cashOutLabel: String? {
        guard !player.inGame, player.cashOut > 0 else { return nil }
        return "Вышел с: \(player.cashOut.asCurrency())"
    }
}

#Preview("Активный игрок") {
    let session = PreviewData.activeSession()
    let player = session.players.first(where: { $0.inGame }) ?? PreviewData.activePlayer()

    return PlayerRow(player: player, session: session)
        .environment(SessionDetailViewModel())
        .padding()
}

#Preview("Игрок вышел") {
    let session = PreviewData.activeSession()
    let player = session.players.first(where: { !$0.inGame }) ?? PreviewData.winnerPlayer()

    return PlayerRow(player: player, session: session)
        .environment(SessionDetailViewModel())
        .padding()
}
