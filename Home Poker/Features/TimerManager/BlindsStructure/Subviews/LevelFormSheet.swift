import SwiftUI

struct LevelFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @Binding var template: TournamentTemplate
    let onSave: (BlindLevel) -> Void

    @State private var smallBlind: Int? = nil
    @State private var bigBlind: Int? = nil
    @State private var ante: Int? = nil
    @State private var minutes: Int? = nil

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
        Form {
                Section {
                    HStack {
                        Text("Small Blind")
                        Spacer()
                        GroupedIntegerTextField(
                            placeholder: "SB",
                            value: $smallBlind,
                            borderStyle: .roundedRect
                        )
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Big Blind")
                        Spacer()
                        GroupedIntegerTextField(
                            placeholder: "BB",
                            value: $bigBlind,
                            borderStyle: .roundedRect
                        )
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Ante")
                        Spacer()
                        GroupedIntegerTextField(
                            placeholder: "Ante",
                            value: $ante,
                            borderStyle: .roundedRect
                        )
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Длительность (мин)")
                        Spacer()
                        GroupedIntegerTextField(
                            placeholder: "Мин.",
                            value: $minutes,
                            borderStyle: .roundedRect
                        )
                            .frame(width: 100)
                    }
                } footer: {
                    if let message = validationMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
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
                    .disabled(!isValid)
                }
        }
        .onAppear {
            if case .edit(let index) = mode,
               template.levels.indices.contains(index) {
                let level = template.levels[index]
                smallBlind = level.smallBlind
                bigBlind = level.bigBlind
                ante = level.ante
                minutes = level.minutes
            } else {
                smallBlind = 100
                bigBlind = 200
                ante = 0
                minutes = 12
            }
        }
    }

    private var isValid: Bool {
        guard let sb = smallBlind, sb > 0,
              let bb = bigBlind, bb > 0,
              let ante = ante, ante >= 0,
              let min = minutes, min > 0
        else {
            return false
        }
        return BlindValidation.validateBlinds(sb: sb, bb: bb) == .valid
    }

    private var validationMessage: String? {
        guard let sb = smallBlind,
              let bb = bigBlind
        else {
            return nil
        }
        let result = BlindValidation.validateBlinds(sb: sb, bb: bb)
        return result.message
    }

    private func saveLevel() {
        guard let sb = smallBlind,
              let bb = bigBlind,
              let anteValue = ante,
              let min = minutes
        else {
            return
        }

        let index = switch mode {
        case .add: template.levels.count + 1
        case .edit(let idx): idx + 1
        }

        let level = BlindLevel(
            index: index,
            smallBlind: sb,
            bigBlind: bb,
            ante: anteValue,
            minutes: min
        )

        onSave(level)
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
