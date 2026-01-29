import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("sessionListShowDetails") private var showSessionListDetails = true
    @AppStorage("timerNotificationsEnabled") private var timerNotificationsEnabled = true

    // Import
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError: Error?
    @State private var importedSession: Session?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()

    #if DEBUG
    @State private var showGenerateConfirm = false
    @State private var isGeneratingDebugSessions = false
    #endif

    var body: some View {
        Form {

            Section {
                Toggle("Показывать подробности", isOn: $showSessionListDetails)
            }
            header: {
                Text("Список сессий")
            }
            footer: {
                Text("Когда выключено — в списке отображается только название и дата последней игры.")
                    .font(.footnote)
            }

            Section {
                Toggle("Уведомления при смене уровня", isOn: $timerNotificationsEnabled)
            } header: {
                Text("Таймер блайндов")
            } footer: {
                Text("Получать уведомления при автоматической смене уровня блайндов в турнире")
            }

            Section {
                NavigationLink {
                    KnowledgeBaseView()
                } label: {
                    Label("База знаний", systemImage: "book.fill")
                }
            } header: {
                Text("Помощь")
            }
            
            
            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Импортировать сессию", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Импорт")
            } footer: {
                Text("Импортируйте сессию из файла .pokersession, полученного от другого пользователя.")
                    .font(.footnote)
            }

            #if DEBUG
            Section {
                Button {
                    showGenerateConfirm = true
                } label: {
                    Label("Сгенерировать 1000 сессий", systemImage: "sparkles")
                }
                .disabled(isGeneratingDebugSessions)
            } header: {
                Text("Debug")
            } footer: {
                Text("Добавляет 1000 случайных сессий в базу для тестирования списка.")
                    .font(.footnote)
            }
            #endif
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.pokerSession],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Сессия импортирована", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            if let session = importedSession {
                Text("Сессия «\(session.sessionTitle)» успешно импортирована")
            }
        }
        .alert("Ошибка импорта", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError?.localizedDescription ?? "Не удалось импортировать сессию")
        }
        #if DEBUG
        .alert("Сгенерировать 1000 сессий?", isPresented: $showGenerateConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Сгенерировать", role: .destructive) {
                generateRandomSessions(count: 1000)
            }
        } message: {
            Text("Это добавит 1000 случайных записей в базу данных.")
        }
        #endif
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            importSession(from: fileURL)
        case .failure(let error):
            importError = error
            showImportError = true
        }
    }

    private func importSession(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw TransferError.fileAccessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let session = try transferService.importSession(from: data, into: context)

            importedSession = session
            showImportSuccess = true
        } catch {
            importError = error
            showImportError = true
        }
    }

    #if DEBUG
    private func generateRandomSessions(count: Int) {
        guard count > 0 else { return }
        isGeneratingDebugSessions = true
        defer { isGeneratingDebugSessions = false }

        let titles = [
            "Home Game",
            "Friday Night",
            "Deep Stack",
            "Turbo",
            "High Rollers",
            "Weekend Session",
            "Practice",
            "Private Table",
            "Afterparty",
            "Midweek"
        ]

        let locations = [
            "Moscow",
            "Saint Petersburg",
            "Sochi",
            "Kazan",
            "Novosibirsk",
            "Online",
            "Private Club",
            "Home"
        ]

        for index in 1...count {
            let sessionType = [SessionType.cash, SessionType.tournament].randomElement() ?? .cash
            let gameType = [GameType.NLHoldem, GameType.PLO4].randomElement() ?? .NLHoldem
            let status = [SessionStatus.active, .awaitingForSettlements, .finished].randomElement() ?? .active
            let startTime = Date().addingTimeInterval(-Double.random(in: 0...(60 * 60 * 24 * 730)))

            let title = "\(titles.randomElement() ?? "Session") \(index)"
            let location = locations.randomElement() ?? "Home"

            var input = NewSessionInput(
                startTime: startTime,
                title: title,
                location: location,
                gameType: gameType,
                sessionType: sessionType,
                cashToChipsRatio: nil,
                entryFee: nil,
                startingStack: nil,
                allowReEntry: nil,
                smallBlind: nil,
                bigBlind: nil,
                ante: nil
            )

            if sessionType == .cash {
                input.cashToChipsRatio = [1, 2, 5, 10].randomElement() ?? 1
                let sb = [25, 50, 100, 200, 500].randomElement() ?? 50
                input.smallBlind = sb
                input.bigBlind = sb * 2
                input.ante = [0, 0, 0, 25, 50].randomElement() ?? 0
            } else {
                input.entryFee = [1000, 2000, 5000, 10000].randomElement() ?? 1000
                input.startingStack = [20000, 30000, 50000, 100000].randomElement() ?? 20000
                input.allowReEntry = Bool.random()
                let sb = [50, 100, 200].randomElement() ?? 50
                input.smallBlind = sb
                input.bigBlind = sb * 2
                input.ante = [0, 25, 50].randomElement() ?? 0
            }

            let session = Session(
                startTime: input.startTime,
                location: input.location.trimmed,
                gameType: input.gameType,
                sessionType: input.sessionType,
                status: status,
                sessionTitle: input.title.trimmed
            )

            if input.sessionType == .cash {
                if let ratio = input.cashToChipsRatio, ratio > 0 {
                    session.chipsToCashRatio = ratio
                }
            }

            if input.sessionType == .tournament {
                session.entryFee = input.entryFee
                session.startingStack = input.startingStack
                session.allowReEntry = input.allowReEntry ?? false
            }

            if let sb = input.smallBlind, sb > 0 {
                session.smallBlind = sb
            }
            if let bb = input.bigBlind, bb > 0 {
                session.bigBlind = bb
            }
            if let ante = input.ante, ante >= 0 {
                session.ante = ante
            }

            context.insert(session)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to generate sessions: \(error)")
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
