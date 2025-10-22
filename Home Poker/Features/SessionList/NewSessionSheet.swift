import SwiftUI
import SwiftData

struct NewSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Date()
    @State private var location: String = ""
    @State private var gameType: GameType = .NLHoldem
    
    @State private var smallBlindText: String = ""
    @State private var bigBlindText: String = ""
    @State private var anteText: String = ""
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
                        TextField("SB", text: $smallBlindText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .small)
                            .frame(maxWidth: 120)
                            .onChange(of: smallBlindText) { _, newValue in
                                if !bigManuallyEdited {
                                    if let sb = newValue.positiveInt {
                                        bigBlindText = String(sb * 2)
                                    } else {
                                        bigBlindText = ""
                                    }
                                }
                            }
                    }
                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", text: $bigBlindText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .big)
                            .frame(maxWidth: 120)
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big {
                            bigManuallyEdited = true
                        }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $anteText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)
                    }
                }
                header: {
                    Text("Блайнды")
                        .font(.caption)
                }
                footer: {
                    if let sb = smallBlindText.positiveInt, let bb = bigBlindText.positiveInt {
                        HStack {
                            Text("Итог")
                            Spacer()
                            if let ante = anteText.nonNegativeInt, ante > 0 {
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
        if let sb = smallBlindText.positiveInt { session.smallBlind = sb }
        if let bb = bigBlindText.positiveInt { session.bigBlind = bb }
        if let ante = anteText.nonNegativeInt { session.ante = ante }
        
        context.insert(session)
        dismiss()
    }
}

#Preview {
    NewSessionSheet()
        .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankEntry.self], inMemory: true)
}
