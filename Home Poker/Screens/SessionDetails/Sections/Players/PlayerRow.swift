import SwiftUI

struct PlayerRow: View {
    var player: Player
    
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
                        player.inGame = true
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
            AddOnSheet(player: player)
        }
        .sheet(isPresented: $showingCashOutSheet) {
            CashOutSheet(player: player)
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        return "₽\(amount)"
    }
}

#Preview {
    let player = Player(name: "Илья", inGame: true)
    // Начальный закуп на 2000 через транзакцию
    _ = Transaction(type: .buyIn, amount: 2000, player: player)
    return PlayerRow(player: player)
}
