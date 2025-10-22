import SwiftUI
import SwiftData

struct NewSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Date()
    @State private var location: String = ""
    @State private var gameType: GameType = .NLHoldem
    
    @State private var smallBlind: Int? = nil
    @State private var bigBlind: Int? = nil
    @State private var ante: Int? = nil
    @State private var bigManuallyEdited = false
    @FocusState private var focusedField: Field?
    
    private enum Field { case small, big }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Начало", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    TextField("Место проведения", text: $location)
                    
                    Picker("Игра", selection: $gameType) {
                        Text(GameType.NLHoldem.rawValue).tag(GameType.NLHoldem)
                        Text(GameType.PLO4.rawValue).tag(GameType.PLO4)
                    }
                }
                
                Section {
                    HStack {
                        Text("Small Blind")
                        Spacer()
                        TextField("SB", value: $smallBlind, format: .number)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .small)
                            .frame(maxWidth: 120)
                            .keyboardType(.numberPad)
                            .onChange(of: smallBlind) { _, newValue in
                                if !bigManuallyEdited {
                                    bigBlind = newValue.map { $0 * 2 }
                                }
                            }
                    }
                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", value: $bigBlind, format: .number)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .big)
                            .frame(maxWidth: 120)
                            .keyboardType(.numberPad)
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big {
                            bigManuallyEdited = true
                        }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", value: $ante, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .keyboardType(.numberPad)
                    }
                }
                header: {
                    Text("Блайнды")
                        .font(.caption)
                }
                footer: {
                    if let sb = smallBlind, let bb = bigBlind {
                        HStack {
                            Text("Итог")
                            Spacer()
                            if let ante = ante, ante > 0 {
                                Text("\(sb)/\(bb) (Анте: \(ante))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(sb)/\(bb)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Укажите блайнды. Big Blind по умолчанию = 2×Small Blind.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Новая сессия")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: createNewSession)
                        .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        location.nonEmptyTrimmed != nil
    }
    
    private func createNewSession() {
        let session = Session(
            startTime: startTime,
            location: location.trimmed,
            gameType: gameType,
            status: .active
        )
        if let sb = smallBlind, sb > 0 { session.smallBlind = sb }
        if let bb = bigBlind, bb > 0 { session.bigBlind = bb }
        if let ante = ante, ante >= 0 { session.ante = ante }
        
        context.insert(session)
        dismiss()
    }
}

#Preview {
    NewSessionSheet()
        .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self], inMemory: true)
}
