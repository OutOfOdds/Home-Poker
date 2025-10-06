import SwiftUI
import SwiftData
import Observation

struct SessionDetailView: View {
    @Bindable var session: Session
    
    @State private var showAddPlayer = false
    @State private var showAddExpense = false
    
    @State private var editedLocation = ""
    @State private var showingLocationAlert = false
    
    @State private var showingBlindsSheet = false
    @State private var tempSmallBlindText: String = ""
    @State private var tempBigBlindText: String = ""
    @State private var tempAnteText: String = ""
    @State private var bigManuallyEdited = false
    
    @FocusState private var focusedField: Field?
    private enum Field { case small, big }
    
    // MARK: - Body
    var body: some View {
        List {
            infoSection
            bankStatsSection
            
            if !session.players.isEmpty {
                playersSection
            }
            
            addPlayerSection
                .listSectionSpacing(.custom(8))
            addExpenseSection
                .listSectionSpacing(.custom(8))
        }
        .navigationTitle(session.status == .active ? "Активная сессия" : "Завершенная сессия")
        .navigationBarTitleDisplayMode(.large)
        
        // MARK: Sheets
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerView(session: session)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(session: session)
        }
        .sheet(isPresented: $showingBlindsSheet) {
            blindsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        
        // MARK: Alerts
        .alert("Изменить место", isPresented: $showingLocationAlert) {
            TextField("Место проведения", text: $editedLocation)
            Button("Сохранить") {
                session.location = editedLocation
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Введите новое место проведения")
        }
    }
}

// MARK: - Sections
private extension SessionDetailView {
    var infoSection: some View {
        Section {
            // Дата и время начала
            HStack {
                Text("Начало:")
                    .foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            
            // Место проведения
            HStack {
                Text("Место:")
                Spacer()
                Text(session.location.isEmpty ? "Нажмите для редактирования" : session.location)
                    .onTapGesture {
                        editedLocation = session.location
                        showingLocationAlert = true
                    }
            }
            .foregroundColor(.secondary)
            
            // Тип игры
            HStack {
                Text("Игра:")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $session.gameType) {
                    ForEach([GameType.NLHoldem, GameType.PLO4], id: \.self) { gameType in
                        Text(gameType.rawValue).tag(gameType)
                    }
                }
                .pickerStyle(.automatic)
            }
            
            // Блайнды
            HStack {
                Text("Блайнды:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(blindsDisplayText())
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        // Инициализация временных значений текущими
                        tempSmallBlindText = session.smallBlind > 0 ? String(session.smallBlind) : ""
                        tempBigBlindText = session.bigBlind > 0 ? String(session.bigBlind) : ""
                        tempAnteText = session.ante > 0 ? String(session.ante) : ""
                        bigManuallyEdited = false
                        showingBlindsSheet = true
                    }
            }
            
            // Продолжительность
            HStack {
                Text("Продолжительность:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(session.duration.formattedDuration)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var bankStatsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Общий закуп")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("₽\(session.totalBuyIns)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center) {
                        Text("В игре")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("₽\(session.bankInGame)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Выведено")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("₽\(session.bankWithdrawn)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                ForEach(session.expenses, id: \.id) { expense in
                    Text("Расходы: ₽\(expense.amount) — \(expense.note)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
            }
        }
    }
    
    var playersSection: some View {
        Section {
            ForEach(session.players, id: \.id) { player in
                PlayerRow(player: player)
            }
        } header: {
            HStack {
                Text("Игроки (\(session.players.count))")
                Spacer()
                Text("Активных: \(session.activePlayers.count)")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
    }
    
    var addPlayerSection: some View {
        Section {
            Button {
                showAddPlayer = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Добавить игрока")
                }
            }
        }
    }
    
    var addExpenseSection: some View {
        Section {
            Button {
                showAddExpense = true
            } label: {
                HStack {
                    Image(systemName: "cart.fill.badge.plus")
                    Text("Добавить расходы")
                }
            }
        }
    }
}

// MARK: - Blinds Sheet
private extension SessionDetailView {
    var blindsSheet: some View {
        Form {
            Text("Блайнды")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Small Blind
                HStack {
                    Text("Small Blind")
                    Spacer()
                    TextField("SB", text: $tempSmallBlindText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .small)
                        .frame(maxWidth: 200)
                        .onChange(of: tempSmallBlindText) { _, newValue in
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                tempSmallBlindText = digits
                                return
                            }
                            if !bigManuallyEdited {
                                if let sb = Int(digits), sb > 0 {
                                    tempBigBlindText = String(sb * 2)
                                } else {
                                    tempBigBlindText = ""
                                }
                            }
                        }
                }
                
                // Big Blind
                HStack {
                    Text("Big Blind")
                    Spacer()
                    TextField("BB", text: $tempBigBlindText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .big)
                        .frame(maxWidth: 200)
                        .onChange(of: tempBigBlindText) { _, newValue in
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                tempBigBlindText = digits
                            }
                        }
                }
                .onChange(of: focusedField) { _, newValue in
                    if newValue == .big {
                        bigManuallyEdited = true
                    }
                }
                
                // Ante
                HStack {
                    Text("Ante")
                    Spacer()
                    TextField("Ante", text: $tempAnteText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 200)
                        .onChange(of: tempAnteText) { _, newValue in
                            let digits = digitsOnly(newValue)
                            if digits != newValue {
                                tempAnteText = digits
                            }
                        }
                }
            }
            .padding(.horizontal)
            
            // Итог / подсказка
            HStack {
                Text("Итог")
                Spacer()
                if let sb = Int(tempSmallBlindText), let bb = Int(tempBigBlindText), sb > 0, bb > 0 {
                    if let ante = Int(tempAnteText), ante > 0 {
                        Text("\(sb)/\(bb) (Анте: \(ante))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(sb)/\(bb)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Укажите блайнды")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Кнопки
            HStack {
                Button("Отмена") {
                    showingBlindsSheet = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Сохранить") {
                    session.smallBlind = Int(tempSmallBlindText) ?? 0
                    session.bigBlind = Int(tempBigBlindText) ?? 0
                    session.ante = Int(tempAnteText) ?? 0
                    showingBlindsSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidBlindsInput)
            }
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Helpers
private extension SessionDetailView {
    var isValidBlindsInput: Bool {
        guard let sb = Int(tempSmallBlindText), let bb = Int(tempBigBlindText) else { return false }
        return sb > 0 && bb > 0
    }
    
    func blindsDisplayText() -> String {
        if session.smallBlind == 0 && session.bigBlind == 0 && session.ante == 0 {
            return "Нажмите для указания"
        }
        var base = "\(formatCurrency(session.smallBlind))/\(formatCurrency(session.bigBlind))"
        if session.ante > 0 {
            base += " (Анте: \(formatCurrency(session.ante)))"
        }
        return base
    }
    
    func formatCurrency(_ amount: Int) -> String {
        "₽\(amount)"
    }
    
    func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}

// MARK: - Duration formatter
private extension TimeInterval {
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "0 мин"
    }
}

#Preview {
    // Тестовая сессия с игроками
    let session = Session(
        startTime: Date().addingTimeInterval(-60 * 60 * 3),
        location: "Клуб «Флоп»",
        gameType: .NLHoldem, status: .active
    )
    let p1 = Player(name: "Илья", isActive: true, buyIn: 2000)
    let p2 = Player(name: "Андрей", isActive: false, buyIn: 3000)
    p2.cashOut = 4500
    session.players = [p1, p2]
    
    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(for: [Session.self, Player.self], inMemory: true)
}
