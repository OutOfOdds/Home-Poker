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
                        TextField("SB", text: $smallBlindText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .small)
                            .frame(maxWidth: 120)
                            .onChange(of: smallBlindText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue {
                                    smallBlindText = digits
                                    return
                                }
                                if !bigManuallyEdited {
                                    if let sb = Int(digits), sb > 0 {
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
                        TextField("BB", text: $bigBlindText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .big)
                            .frame(maxWidth: 120)
                            .onChange(of: bigBlindText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue {
                                    bigBlindText = digits
                                }
                            }
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big {
                            bigManuallyEdited = true
                        }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $anteText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)
                            .onChange(of: anteText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue {
                                    anteText = digits
                                }
                            }
                    }
                }
                header: {
                    Text("Блайнды")
                        .font(.caption)
                }
                footer: {
                    if let sb = Int(smallBlindText), let bb = Int(bigBlindText), sb > 0, bb > 0 {
                        HStack {
                            Text("Итог")
                            Spacer()
                            if let ante = Int(anteText), ante > 0 {
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
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createNewSession() {
        let session = Session(
            startTime: startTime,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            gameType: gameType,
            status: .active
        )
        if let sb = Int(smallBlindText) { session.smallBlind = sb }
        if let bb = Int(bigBlindText) { session.bigBlind = bb }
        if let ante = Int(anteText) { session.ante = ante }
        
        context.insert(session)
        dismiss()
    }
    
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}

#Preview {
    NewSessionSheet()
        .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self], inMemory: true)
}
