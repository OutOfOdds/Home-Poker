import SwiftUI
import SwiftData

struct NewSessionSheet: View {
    let sessionType: SessionType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date = Date()
    @State private var sessionTitle: String = ""
    @State private var location: String = ""
    @State private var gameType: GameType = .NLHoldem

    // Кеш-игра поля
    @State private var cashToChipsRatio: Int? = nil

    // Турнир поля
    @State private var entryFee: Int? = nil
    @State private var startingStack: Int? = nil
    @State private var allowReEntry: Bool = false

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

                if sessionType == .cash {
                    cashGameSection
                }

                if sessionType == .tournament {
                    tournamentSection
                }

                blindSection
            }
            .navigationTitle(sessionType == .cash ? "Новая кеш-игра" : "Новый турнир")
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
        }
    }

    private var cashGameSection: some View {
        Section {
            HStack {
                Text("1 фишка равна:")
                Spacer()
                TextField("Наличные", value: $cashToChipsRatio, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .keyboardType(.numberPad)
            }
        } footer: {
            Text("прим. 1 фишка = 10 у.e.")
        }
    }

    private var tournamentSection: some View {
        Section("Параметры турнира") {
            HStack {
                Text("Бай-ин")
                Spacer()
                TextField("0", value: $entryFee, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .keyboardType(.numberPad)
            }

            HStack {
                Text("Стартовый стек")
                Spacer()
                TextField("0", value: $startingStack, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .keyboardType(.numberPad)
            }

            Toggle("Разрешить Re-entry", isOn: $allowReEntry)
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
        guard location.nonEmptyTrimmed != nil else { return false }

        switch sessionType {
        case .cash:
            return cashToChipsRatio != nil
        case .tournament:
            return entryFee != nil && startingStack != nil
        }
    }
    
    private func createNewSession() {
        let input = NewSessionInput(
            startTime: startTime,
            title: sessionTitle,
            location: location,
            gameType: gameType,
            sessionType: sessionType,
            cashToChipsRatio: cashToChipsRatio,
            entryFee: entryFee,
            startingStack: startingStack,
            allowReEntry: allowReEntry,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            ante: ante
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

#Preview("Кеш-игра") {
    NewSessionSheet(sessionType: .cash)
        .modelContainer(PreviewData.previewContainer)
}

#Preview("Турнир") {
    NewSessionSheet(sessionType: .tournament)
        .modelContainer(PreviewData.previewContainer)
}
