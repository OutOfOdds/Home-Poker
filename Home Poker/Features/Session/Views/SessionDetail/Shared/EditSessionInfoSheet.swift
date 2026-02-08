import SwiftUI
import SwiftData

struct EditSessionInfoSheet: View {
    @Bindable var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date
    @State private var gameType: GameType
    @State private var cashToChipsRatio: Int?
    @State private var smallBlind: Int?
    @State private var bigBlind: Int?
    @State private var ante: Int?

    init(session: Session) {
        self.session = session
        _startTime = State(initialValue: session.startTime)
        _gameType = State(initialValue: session.gameType)
        _cashToChipsRatio = State(initialValue: session.chipsToCashRatio == 0 ? nil : session.chipsToCashRatio)
        _smallBlind = State(initialValue: session.smallBlind == 0 ? nil : session.smallBlind)
        _bigBlind = State(initialValue: session.bigBlind == 0 ? nil : session.bigBlind)
        _ante = State(initialValue: session.ante == 0 ? nil : session.ante)
    }

    var body: some View {
        NavigationStack {
            Form {
                sessionInfoSection
                blindSection
            }
            .toolbar {
                toolBar
            }
        }
    }

    // MARK: - Sections

    private var sessionInfoSection: some View {
        Section {
            DatePicker("Начало", selection: $startTime, displayedComponents: [.date, .hourAndMinute])

            Picker("Игра", selection: $gameType) {
                Text(GameType.NLHoldem.rawValue).tag(GameType.NLHoldem)
                Text(GameType.PLO4.rawValue).tag(GameType.PLO4)
            }

            HStack {
                Text("1 фишка равна:")
                Spacer()
                GroupedIntegerTextField(
                    placeholder: "Наличные",
                    value: $cashToChipsRatio
                )
                    .frame(maxWidth: 120)
            }
        } header: {
            Text("Основная информация")
        } footer: {
            Text("прим. 1 фишка = 10 у.e.")
        }
    }

    private var blindSection: some View {
        Section {
            HStack {
                Text("Small Blind")
                Spacer()
                GroupedIntegerTextField(
                    placeholder: "SB",
                    value: $smallBlind
                )
                    .frame(maxWidth: 120)
            }

            HStack {
                Text("Big Blind")
                Spacer()
                GroupedIntegerTextField(
                    placeholder: "BB",
                    value: $bigBlind
                )
                    .frame(maxWidth: 120)
            }

            HStack {
                Text("Ante")
                Spacer()
                GroupedIntegerTextField(
                    placeholder: "Ante",
                    value: $ante
                )
                    .frame(maxWidth: 120)
            }
        } header: {
            Text("Блайнды")
        } footer: {
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
                Text("Укажите блайнды")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolBar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Отмена") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Сохранить", action: saveChanges)
                .disabled(!canSave)
        }
    }

    // MARK: - Validation & Saving

    private var canSave: Bool {
        cashToChipsRatio != nil
    }

    private func saveChanges() {
        session.startTime = startTime
        session.gameType = gameType
        session.chipsToCashRatio = cashToChipsRatio ?? 0
        session.smallBlind = smallBlind ?? 0
        session.bigBlind = bigBlind ?? 0
        session.ante = ante ?? 0
        session.applyAutomaticHeader()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let session = PreviewData.activeSession()
    return EditSessionInfoSheet(session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
}
