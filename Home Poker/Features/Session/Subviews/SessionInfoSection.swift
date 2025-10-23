import SwiftUI
import SwiftData

struct SessionInfoSection: View {
    @Bindable var session: Session
    @Binding var showingBlindsSheet: Bool
    
    @State private var editedLocation = ""
    @State private var showingLocationAlert = false


    @State private var editedSessionTitle = ""
    @State private var showingTitleAlert = false

    
    var body: some View {
        Section {
            HStack {
                Text("Сессия:")
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
                Text(session.sessionTitle.isEmpty ? "Нажмите для редактирования" : session.sessionTitle)
                    .onTapGesture {
                        editedSessionTitle = session.sessionTitle
                        showingTitleAlert = true
                    }
                    .font(.headline)

            }
            // Место
            HStack {
                Text("Место:")
                    .italic()
                    .foregroundColor(.secondary)
                Spacer()
                Text(session.location.isEmpty ? "Нажмите для редактирования" : session.location)
                    .onTapGesture {
                        editedLocation = session.location
                        showingLocationAlert = true
                    }
                    .font(.headline)

            }

            // Начало
            HStack {
                Text("Начало:")
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
                DatePicker("", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            // Игра
            HStack {
                Text("Игра:")
                    .foregroundColor(.secondary)
                    .italic()
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
                    .italic()
                Spacer()
                Text(blindsDisplayText)
                    .fontDesign(.monospaced)
                    .onTapGesture { showingBlindsSheet = true }
            }
        }
        .alert("Изменить место", isPresented: $showingLocationAlert) {
            TextField("Место проведения", text: $editedLocation)
            Button("Сохранить") { session.location = editedLocation }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Введите новое место проведения")
        }
        .alert("Изменить название", isPresented: $showingTitleAlert) {
            TextField("Название", text: $editedSessionTitle)
            Button("Сохранить") { session.sessionTitle = editedSessionTitle }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Введите новое название для сессии")
        }
    }
    
    private var blindsDisplayText: String {
        if session.smallBlind == 0 && session.bigBlind == 0 && session.ante == 0 {
            return "Нажмите для указания"
        }
        var base = "\(session.smallBlind.asCurrency())/\(session.bigBlind.asCurrency())"
        if session.ante > 0 {
            base += " (Анте: \(session.ante.asCurrency()))"
        }
        return base
    }
}

#Preview {
    let session = PreviewData.activeSession()

    NavigationStack {
        List {
            SessionInfoSection(session: session, showingBlindsSheet: .constant(false))
        }
        .navigationTitle("Превью статистики банка")
    }
    .modelContainer(for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
    .environment(SessionDetailViewModel())
}

