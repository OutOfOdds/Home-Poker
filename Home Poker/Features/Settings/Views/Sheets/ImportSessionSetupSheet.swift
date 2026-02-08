import SwiftUI

struct ImportSessionSetupSheet: View {
    let clubs: [Club]
    let importData: Data
    let transferService: SessionTransferServiceProtocol
    let onConfirm: (Club, [String]) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedClubID: UUID?
    @State private var missingMemberNames: [String] = []
    @State private var selectedMissingMemberNames: Set<String> = []
    @State private var analysisError: String?

    private var sortedClubs: [Club] {
        clubs.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var selectedClub: Club? {
        guard let selectedClubID else { return nil }
        return sortedClubs.first(where: { $0.id == selectedClubID })
    }

    private var canConfirm: Bool {
        selectedClub != nil && analysisError == nil
    }

    var body: some View {
        FormSheetView(
            title: "Параметры импорта",
            confirmTitle: "Импортировать",
            isConfirmDisabled: !canConfirm,
            confirmAction: confirm,
            cancelAction: cancel
        ) {
            Form {
                Section("Клуб") {
                    Picker("Клуб", selection: $selectedClubID) {
                        ForEach(sortedClubs) { club in
                            Text(club.name).tag(Optional(club.id))
                        }
                    }
                }

                Section("Недостающие участники") {
                    if let analysisError {
                        Text(analysisError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if missingMemberNames.isEmpty {
                        Text("Все игроки из файла уже есть в участниках клуба.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Выберите, кого добавить в клуб перед импортом.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(missingMemberNames, id: \.self) { name in
                            Toggle(
                                name,
                                isOn: Binding(
                                    get: { selectedMissingMemberNames.contains(name) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedMissingMemberNames.insert(name)
                                        } else {
                                            selectedMissingMemberNames.remove(name)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            if selectedClubID == nil {
                selectedClubID = sortedClubs.first?.id
            }
            refreshMissingMembers()
        }
        .onChange(of: selectedClubID) { _, _ in
            refreshMissingMembers()
        }
    }

    private func refreshMissingMembers() {
        guard let selectedClub else {
            missingMemberNames = []
            selectedMissingMemberNames = []
            analysisError = nil
            return
        }

        do {
            let names = try transferService.missingClubMemberNames(from: importData, in: selectedClub)
            missingMemberNames = names
            selectedMissingMemberNames = Set(names)
            analysisError = nil
        } catch {
            missingMemberNames = []
            selectedMissingMemberNames = []
            analysisError = error.localizedDescription
        }
    }

    private func confirm() {
        guard let selectedClub else { return }
        let selectedNames = missingMemberNames.filter { selectedMissingMemberNames.contains($0) }
        onConfirm(selectedClub, selectedNames)
        dismiss()
    }

    private func cancel() {
        onCancel()
        dismiss()
    }
}

#Preview {
    let clubA = Club(name: "Клуб A")
    let clubB = Club(name: "Клуб B")
    let service = SessionTransferService()

    return ImportSessionSetupSheet(
        clubs: [clubA, clubB],
        importData: Data(),
        transferService: service
    ) { _, _ in
    } onCancel: {
    }
}
