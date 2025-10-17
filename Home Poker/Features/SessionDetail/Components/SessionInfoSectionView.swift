import SwiftUI

struct SessionInfoSectionView: View {
    @Bindable var session: Session
    @Binding var showingBlindsSheet: Bool
    
    @State private var editedLocation = ""
    @State private var showingLocationAlert = false
    
    var body: some View {
        Section {
            // Начало
            HStack {
                Text("Начало:")
                    .foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            // Место
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
            // Игра
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
                Text(blindsDisplayText)
                    .foregroundColor(.secondary)
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
    }
    
    private var blindsDisplayText: String {
        if session.smallBlind == 0 && session.bigBlind == 0 && session.ante == 0 {
            return "Нажмите для указания"
        }
        var base = "₽\(session.smallBlind)/₽\(session.bigBlind)"
        if session.ante > 0 {
            base += " (Анте: ₽\(session.ante))"
        }
        return base
    }
}
