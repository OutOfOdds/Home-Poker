import SwiftUI
import SwiftData

struct PlayersSectionView: View {
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
                            PlayerTransactionsView(player: player)
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
                        Text("В игре (\(activePlayers.count))")
                            .foregroundStyle(.green)
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
                            PlayerTransactionsView(player: player)
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
                        Text("Завершившие (\(finishedPlayers.count))")
                            .foregroundStyle(.red)
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
    let session = Session(
        startTime: Date().addingTimeInterval(-60 * 60 * 3),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem,
        status: .active
    )
    
    // Игрок 1 - в игре, положительный результат
    let p1 = Player(name: "Илья", inGame: true)
    p1.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p1),
        PlayerTransaction(type: .addOn, amount: 1000, player: p1)
    ])
    
    // Игрок 2 - завершил, отрицательный результат
    let p2 = Player(name: "Андрей", inGame: false)
    p2.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p2),
        PlayerTransaction(type: .cashOut, amount: 1500, player: p2)
    ])
    
    // Игрок 3 - в игре
    let p3 = Player(name: "Сергей", inGame: true)
    p3.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2000, player: p3)
    ])
    
    // Игрок 4 - завершил, небольшой минус
    let p4 = Player(name: "Дмитрий", inGame: false)
    p4.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2500, player: p4),
        PlayerTransaction(type: .cashOut, amount: 1800, player: p4)
    ])
    
    // Игрок 5 - в игре, докупался
    let p5 = Player(name: "Алексей", inGame: true)
    p5.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 1500, player: p5),
        PlayerTransaction(type: .addOn, amount: 1500, player: p5)
    ])
    
    // Игрок 6 - завершил, в нуле
    let p6 = Player(name: "Павел", inGame: false)
    p6.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 3000, player: p6),
        PlayerTransaction(type: .cashOut, amount: 3000, player: p6)
    ])
    
    // Игрок 7 - в игре, большой закуп
    let p7 = Player(name: "Роман", inGame: true)
    p7.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 5000, player: p7)
    ])
    
    // Игрок 8 - завершил, большой плюс
    let p8 = Player(name: "Виктор", inGame: false)
    p8.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 1800, player: p8),
        PlayerTransaction(type: .addOn, amount: 500, player: p8),
        PlayerTransaction(type: .cashOut, amount: 4500, player: p8)
    ])
    
    // Игрок 9 - в игре
    let p9 = Player(name: "Никита", inGame: true)
    p9.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 2200, player: p9)
    ])
    
    // Игрок 10 - завершил, большой минус
    let p10 = Player(name: "Максим", inGame: false)
    p10.transactions.append(contentsOf: [
        PlayerTransaction(type: .buyIn, amount: 4000, player: p10),
        PlayerTransaction(type: .addOn, amount: 2000, player: p10),
        PlayerTransaction(type: .cashOut, amount: 2500, player: p10)
    ])
    
    session.players = [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10]
    
    return NavigationStack {
        List {
            PlayersSectionView(session: session)
        }
    }
    .environment(SessionDetailViewModel())
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self],
        inMemory: true
    )
}
