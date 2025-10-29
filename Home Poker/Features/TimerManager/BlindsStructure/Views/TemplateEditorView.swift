import SwiftUI

struct TemplateEditorView: View {
    @State private var template: TournamentTemplate
    @State private var validationWarnings: [ValidationWarning] = []
    @State private var sheetMode: LevelFormSheet.Mode?

    let onSave: (TournamentTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    init(template: TournamentTemplate, onSave: @escaping (TournamentTemplate) -> Void) {
        self._template = State(initialValue: template)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            // Template name
            Section("Название") {
                TextField("Название турнира", text: $template.name)
            }

            // Validation warnings
            if !validationWarnings.isEmpty {
                Section {
                    ForEach(validationWarnings) { warning in
                        HStack(spacing: 8) {
                            Image(systemName: warning.severity == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundStyle(warning.severity == .error ? .red : .orange)
                            Text(warning.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Levels list
            Section("Структура блайндов") {
                ForEach(Array(template.levels.enumerated()), id: \.element.id) { index, level in
                    Button {
                        sheetMode = .edit(index: index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Уровень \(level.index)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(level.formattedBlinds)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(level.minutes) мин")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    sheetMode = .add
                } label: {
                    Label("Добавить уровень", systemImage: "plus.circle.fill")
                }
            }

            // Default settings
            Section("Настройки по умолчанию") {
                HStack {
                    Text("Игроков")
                    Spacer()
                    TextField("", value: $template.defaultPlayers, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Стартовый стек")
                    Spacer()
                    TextField("", value: $template.defaultStartingStack, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
        }
        .navigationTitle("Редактор шаблона")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    onSave(template)
                    dismiss()
                }
                .disabled(!isEditValid)
            }
        }
        .sheet(item: $sheetMode) { mode in
            LevelFormSheet(
                mode: mode,
                template: $template,
                onSave: { level in
                    switch mode {
                    case .add:
                        addLevel(level)
                    case .edit(let index):
                        updateLevel(at: index, with: level)
                    }
                }
            )
        }
        .onChange(of: template.levels) {
            validateStructure()
        }
        .onAppear {
            validateStructure()
        }
    }

    // MARK: - Computed Properties

    private var isEditValid: Bool {
        !template.name.isEmpty
        && !template.levels.isEmpty
        && validationWarnings.filter { $0.severity == .error }.isEmpty
    }

    // MARK: - Helpers

    private func addLevel(_ level: BlindLevel) {
        template.levels.append(level)
        reindexLevels()
        validateStructure()
    }

    private func updateLevel(at index: Int, with level: BlindLevel) {
        guard template.levels.indices.contains(index) else { return }
        template.levels[index] = level
        validateStructure()
    }

    private func reindexLevels() {
        for index in template.levels.indices {
            template.levels[index].index = index + 1
        }
    }

    private func validateStructure() {
        validationWarnings = BlindValidation.validateStructure(levels: template.levels)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var template = BuiltInTemplates.standardMedium

    return NavigationStack {
        TemplateEditorView(
            template: template,
            onSave: { edited in
                print("Saved: \(edited.name)")
            }
        )
    }
}
