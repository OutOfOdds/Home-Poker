import SwiftUI
import SwiftData

struct AddClubMemberSheet: View {
    let club: Club
    let existingNames: Set<String>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var memberName = ""
    @State private var validationError: String?

    var body: some View {
        FormSheetView(
            title: "Добавить участника",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSave,
            confirmAction: addMember,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Имя участника") {
                    TextField("Имя", text: $memberName)
                        .textInputAutocapitalization(.words)

                    if let validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onChange(of: memberName) { _, _ in
            validate()
        }
    }

    private var canSave: Bool {
        guard let name = memberName.nonEmptyTrimmed else { return false }
        return !existingNames.contains(name.lowercased())
    }

    private func validate() {
        guard let name = memberName.nonEmptyTrimmed else {
            validationError = nil
            return
        }
        validationError = existingNames.contains(name.lowercased())
            ? "Участник с таким именем уже есть в клубе"
            : nil
    }

    private func addMember() {
        guard let name = memberName.nonEmptyTrimmed else { return }
        guard !existingNames.contains(name.lowercased()) else { return }

        let member = ClubMember(name: name, club: club)
        club.members.append(member)
        do {
            try context.save()
            dismiss()
        } catch {
            assertionFailure("Failed to add club member: \(error)")
        }
    }
}

#Preview {
    let container = PreviewData.previewContainer
    let context = container.mainContext
    let club = (try? context.fetch(FetchDescriptor<Club>()).first) ?? Club(name: "Домашний клуб")

    return AddClubMemberSheet(
        club: club,
        existingNames: Set(club.members.map { $0.name.lowercased() })
    )
    .modelContainer(container)
}
