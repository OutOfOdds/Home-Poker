import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("sessionListShowDetails") private var showSessionListDetails = true

    // Import
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError: Error?
    @State private var importedSession: Session?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()

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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
