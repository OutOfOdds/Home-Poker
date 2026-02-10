import SwiftUI
import SwiftData

struct CreateClubSheet: View {
    let existingNames: Set<String>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var clubName = ""
    @State private var validationError: String?
    @FocusState private var focusedField: FocusField?

    private enum FocusField {
        case clubName
    }

    var body: some View {
        FormSheetView(
            title: "Создать клуб",
            confirmTitle: "Создать",
            isConfirmDisabled: !canCreate,
            confirmAction: createClub,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Название клуба") {
                    TextField("Название", text: $clubName)
                        .focused($focusedField, equals: .clubName)
                        .textInputAutocapitalization(.words)

                    if let validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onChange(of: clubName) { _, _ in
            validate()
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .clubName
            }
        }
    }

    private var canCreate: Bool {
        guard let name = clubName.nonEmptyTrimmed else { return false }
        return !existingNames.contains(name.lowercased())
    }

    private func validate() {
        guard let name = clubName.nonEmptyTrimmed else {
            validationError = nil
            return
        }
        validationError = existingNames.contains(name.lowercased())
            ? "Клуб с таким названием уже существует"
            : nil
    }

    private func createClub() {
        guard let name = clubName.nonEmptyTrimmed else { return }
        guard !existingNames.contains(name.lowercased()) else { return }

        context.insert(Club(name: name))
        do {
            try context.save()
            dismiss()
        } catch {
            assertionFailure("Failed to create club: \(error)")
        }
    }
}

#Preview {
    CreateClubSheet(existingNames: [])
        .modelContainer(PreviewData.previewContainer)
}
