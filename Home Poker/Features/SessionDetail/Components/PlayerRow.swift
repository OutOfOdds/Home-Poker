import SwiftUI

struct PlayerRow: View {
    var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    @State private var showingBuyInSheet = false
    @State private var showingCashOutSheet = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    
                    HStack {
                        Text(player.name)
                            .font(.headline)
                            .opacity(player.inGame ? 1 : 0.5)
                        if !player.inGame {
                            Text("(вышел)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Закуп: \(player.buyIn.asCurrency())")
                        if !player.inGame {
                            Text("-> Вывод: \(player.cashOut.asCurrency())")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .fontDesign(.monospaced)
                    
                    if !player.inGame {
                        HStack {
                            Text(player.profit.asCurrency())
                                .font(.title3)
                                .bold()
                                .foregroundColor(displayedProfitColor)
                                .fontDesign(.monospaced)
                            Image(systemName: "banknote")
                                .font(.title3)
                                .fontDesign(.monospaced)
                                .foregroundColor(displayedProfitColor)
                        }
                    }
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
                            Image(systemName: "minus.circle.fill")
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
                        viewModel.returnPlayerToGame(player)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.left")
                            Text("Вернуть игрока")
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

#Preview {
    let player = Player(name: "Илья", inGame: true)
    // Начальный закуп на 2000 через транзакцию
    let t1 = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
    player.transactions.append(t1)
    
    let session = Session(
        startTime: Date(),
        location: "Preview Club",
        gameType: .NLHoldem,
        status: .active
    )
    session.players.append(player)
    return PlayerRow(player: player, session: session)
        .environment(SessionDetailViewModel())
}

#Preview("Игрок вышел") {
    let player = Player(name: "Алексей", inGame: false)
    // Закупился и вышел с суммой, чтобы показать "Вышел с:"
    let t1 = PlayerTransaction(type: .buyIn, amount: 3000, player: player)
    let t2 = PlayerTransaction(type: .cashOut, amount: 4500, player: player)
    player.transactions.append(contentsOf: [t1, t2])
    
    let session = Session(
        startTime: Date(),
        location: "Preview Club",
        gameType: .NLHoldem,
        status: .active
    )
    session.players.append(player)
    return PlayerRow(player: player, session: session)
        .environment(SessionDetailViewModel())
}
