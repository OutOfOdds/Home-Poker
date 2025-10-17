import SwiftUI

struct PlayerRow: View {
    var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    
    @State private var showingBuyInSheet = false
    @State private var showingCashOutSheet = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(player.name)
                            .font(.headline)
                        if !player.inGame {
                            Text("(вышел)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Закупка: \(formatCurrency(player.buyIn))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if player.inGame {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(formatCurrency(player.profit))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(player.profit >= 0 ? .green : .red)
                        
                        Text("В игре: \(formatCurrency(player.balance))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else {
                    Spacer()
                    VStack(alignment: .center, spacing: 6) {
                        Text(formatCurrency(player.profit))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(player.profit >= 0 ? .green : .red)
                        if player.cashOut > 0 {
                            Text("Вышел с: \(formatCurrency(player.cashOut))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.returnPlayerToGame(player)
                    } label: {
                        Image(systemName: "arrow.uturn.left")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if player.inGame {
                HStack(spacing: 12) {
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
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingBuyInSheet) {
            PlayerAddOnSheet(player: player)
        }
        .sheet(isPresented: $showingCashOutSheet) {
            PlayerCashOutSheet(player: player, session: session)
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        return "₽\(amount)"
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    // Начальный закуп на 2000 через транзакцию
    _ = PlayerTransaction(type: .buyIn, amount: 2000, player: player)
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
