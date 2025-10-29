import SwiftUI

struct LevelFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @Binding var template: TournamentTemplate
    let onSave: (BlindLevel) -> Void

    @State private var smallBlind: String = ""
    @State private var bigBlind: String = ""
    @State private var ante: String = ""
    @State private var minutes: String = ""

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
                        TextField("SB", text: $smallBlind)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", text: $bigBlind)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $ante)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Длительность (мин)")
                        Spacer()
                        TextField("Мин.", text: $minutes)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
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
                smallBlind = String(level.smallBlind)
                bigBlind = String(level.bigBlind)
                ante = String(level.ante)
                minutes = String(level.minutes)
            } else {
                smallBlind = "100"
                bigBlind = "200"
                ante = "0"
                minutes = "12"
            }
        }
    }

    private var isValid: Bool {
        guard let sb = Int(smallBlind), sb > 0,
              let bb = Int(bigBlind), bb > 0,
              Int(ante) != nil,
              let min = Int(minutes), min > 0
        else {
            return false
        }
        return BlindValidation.validateBlinds(sb: sb, bb: bb) == .valid
    }

    private var validationMessage: String? {
        guard let sb = Int(smallBlind),
              let bb = Int(bigBlind)
        else {
            return nil
        }
        let result = BlindValidation.validateBlinds(sb: sb, bb: bb)
        return result.message
    }

    private func saveLevel() {
        guard let sb = Int(smallBlind),
              let bb = Int(bigBlind),
              let anteValue = Int(ante),
              let min = Int(minutes)
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
