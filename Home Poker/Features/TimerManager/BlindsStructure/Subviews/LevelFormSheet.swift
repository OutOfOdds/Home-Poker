import SwiftUI

struct LevelFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @Binding var template: TournamentTemplate
    let onSave: (BlindLevel) -> Void

    @State private var formState = LevelFormState()

    enum Mode: Identifiable {
        case add
        case edit(index: Int)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let index): return "edit-\(index)"
            }
        }

        var title: String {
            switch self {
            case .add: return "Добавить уровень"
            case .edit(let index): return "Уровень \(index + 1)"
            }
        }

        var buttonText: String {
            switch self {
            case .add: return "Добавить"
            case .edit: return "Сохранить"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                LevelFormFields(formState: $formState)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonText) {
                        saveLevel()
                    }
                    .disabled(!formState.isValid)
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
    }

    private func loadInitialData() {
        switch mode {
        case .add:
            formState.setDefaults()
        case .edit(let index):
            if template.levels.indices.contains(index) {
                formState.load(from: template.levels[index])
            }
        }
    }

    private func saveLevel() {
        switch mode {
        case .add:
            guard let level = formState.createLevel(index: template.levels.count + 1) else { return }
            onSave(level)
        case .edit(let index):
            guard let level = formState.createLevel(index: index + 1) else { return }
            onSave(level)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Level") {
    @Previewable @State var template = BuiltInTemplates.standardMedium

    return LevelFormSheet(
        mode: .add,
        template: $template,
        onSave: { level in
            print("Added: \(level)")
        }
    )
}

#Preview("Edit Level") {
    @Previewable @State var template = BuiltInTemplates.standardMedium

    return LevelFormSheet(
        mode: .edit(index: 0),
        template: $template,
        onSave: { level in
            print("Edited: \(level)")
        }
    )
}
