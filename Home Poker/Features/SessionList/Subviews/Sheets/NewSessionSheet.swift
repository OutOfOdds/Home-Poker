import SwiftUI
import SwiftData

struct NewSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Date()
    @State private var sessionTitle: String = ""
    @State private var location: String = ""
    @State private var gameType: GameType = .NLHoldem
    @State private var cashToChipsRatio: Int? = nil
    
    @State private var smallBlind: Int? = nil
    @State private var bigBlind: Int? = nil
    @State private var ante: Int? = nil
    @State private var bigManuallyEdited = false
    
    
    @FocusState private var focusedField: Field?
    
    private enum Field { case small, big }
    
    var body: some View {
        NavigationStack {
            Form {
                sessionInfoSection
                blindSection
            }
            .navigationTitle("Новая сессия")
            .toolbar {
                toolBar
            }
        }
    }
    
    private var sessionInfoSection: some View {
        Section {
            TextField("Название", text: $sessionTitle)
            DatePicker("Начало", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            TextField("Место проведения", text: $location)
            
            Picker("Игра", selection: $gameType) {
                Text(GameType.NLHoldem.rawValue).tag(GameType.NLHoldem)
                Text(GameType.PLO4.rawValue).tag(GameType.PLO4)
            }
            
            HStack {
                Text("1 фишка равна:")
                Spacer()
                TextField("Наличные", value: $cashToChipsRatio, format: .number)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .big)
                    .frame(maxWidth: 120)
                    .keyboardType(.numberPad)
            }
        } footer: {
            Text("прим. 1 фишка = 10 у.e.")
        }
    }
    
    private var blindSection: some View {
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
    
    @ToolbarContentBuilder
    private var toolBar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Отмена") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Сохранить", action: createNewSession)
                .disabled(!canSave)
        }
    }
    
    private var canSave: Bool {
        location.nonEmptyTrimmed != nil && cashToChipsRatio != nil
    }
    
    private func createNewSession() {
        let input = NewSessionInput(
            startTime: startTime,
            title: sessionTitle,
            location: location,
            gameType: gameType,
            cashToChipsRatio: cashToChipsRatio,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            ante: ante,
        )
        let repository = SwiftDataSessionsRepository(context: context)
        do {
            try repository.createSession(from: input)
            dismiss()
        } catch {
            assertionFailure("Failed to create session: \\(error)")
        }
    }
}

#Preview {
    NewSessionSheet()
        .modelContainer(PreviewData.previewContainer)
}
