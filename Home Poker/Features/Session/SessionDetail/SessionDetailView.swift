import SwiftUI
import SwiftData
import Observation
import TipKit

struct SessionDetailView: View {
    @Bindable var session: Session
    @State private var activeSheet: SheetType?
    @State private var selectedInfoTab: Int = 1
    @Environment(SessionDetailViewModel.self) var viewModel

    // Export/Share
    @State private var sessionTransferFile: SessionTransferFile?
    @State private var showExportError = false
    @State private var exportError: Error?
    private let transferService: SessionTransferServiceProtocol = SessionTransferService()

    private let addPlayerTip = AddPlayerTip()
    private let bankTip = SessionBankTip()
    enum SheetType: Identifiable {
        case addPlayer
        case addExpense
        case editSessionInfo
        case editBlinds
        case editRake
        
        var id: Self { self }
    }
    private var navigationTitle: String {
        session.status.rawValue
    }
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        List {
            Section {
                Picker("", selection: $selectedInfoTab) {
                    Text("Инфо").tag(0)
                    Text("Фишки").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(5)
            
            
            // Условное отображение секций
            if selectedInfoTab == 0 {
                SessionInfoSummary(session: session) {
                    activeSheet = .editSessionInfo
                }
            } else {
                ChipsStatsSection(
                    session: session,
                    showingRakeSheet: Binding(
                        get: { activeSheet == .editRake },
                        set: { if $0 { activeSheet = .editRake } else { activeSheet = nil } }
                    )
                )
            }
            
            if !session.players.isEmpty {
                PlayerList(session: session)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.automatic)
        .sheet(item: $activeSheet) { sheetType in
            sheetContent(for: sheetType)
        }
        
        // MARK: - Toolbar

        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let transferFile = sessionTransferFile {
                    ShareLink(
                        item: transferFile.url,
                        preview: SharePreview(
                            session.sessionTitle,
                            image: Image(systemName: "suit.spade.fill")
                        )
                    ) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        exportSession()
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                }
            }

            ToolbarItem {
                NavigationLink {
                    SessionBankDashboardView(session: session)
                        .environment(viewModel)
                } label: {
                    HStack {
                        Image(systemName: "building.columns")
                        Text("Банк сессии")
                    }
                }
                .popoverTip(bankTip, arrowEdge: .top)
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }

            ToolbarItem {
                Button {
                    activeSheet = .addPlayer
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .popoverTip(addPlayerTip, arrowEdge: .top)
            }
        }
        .alert("Ошибка", isPresented: $bindableViewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bindableViewModel.alertMessage ?? "")
        }
        .onChange(of: session.players.count) { oldValue, newValue in
            if oldValue == 0 && newValue > 0 {
                SessionBankTip.hasAddedFirstPlayer = true
            }
        }
        .alert("Ошибка экспорта", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError?.localizedDescription ?? "Не удалось экспортировать сессию")
        }
    }

    // MARK: - Export Methods

    private func exportSession() {
        do {
            let data = try transferService.exportSession(session)
            let filename = generateFilename(for: session)
            let url = try saveToTemporaryFile(data: data, filename: filename)
            sessionTransferFile = SessionTransferFile(url: url, filename: filename)
        } catch {
            exportError = error
            showExportError = true
        }
    }

    private func generateFilename(for session: Session) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: session.startTime)

        let sanitizedTitle = session.sessionTitle
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        return "\(sanitizedTitle)_\(dateString).pokersession"
    }

    private func saveToTemporaryFile(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }

    // MARK: - Sheet Content
    
    @ViewBuilder
    private func sheetContent(for type: SheetType) -> some View {
        switch type {
        case .addPlayer:
            AddPlayerSheet(session: session)
        case .addExpense:
            AddExpenseSheet(session: session)
        case .editSessionInfo:
            EditSessionInfoSheet(session: session)
        case .editBlinds:
            BlindsEditorSheet(session: session)
        case .editRake:
            RakeAndTipsSheet(session: session)
        }
    }
}

// MARK: - Supporting Types

/// Структура для хранения информации об экспортированном файле сессии
struct SessionTransferFile: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
}

// MARK: - Preview

private func sessionDetailPreview(session: Session) -> some View {
    NavigationStack {
        SessionDetailView(session: session)
            .environment(SessionDetailViewModel())
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
    .task {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        Tips.showAllTipsForTesting()
    }
}

#Preview("Активная сессия") {
    sessionDetailPreview(session: PreviewData.activeSession())
}

#Preview("Пустая сессия с TipKit") {
    sessionDetailPreview(session: PreviewData.emptySession())
}

#Preview("Завершенная сессия") {
    sessionDetailPreview(session: PreviewData.finishedSession())
}
