import SwiftUI

struct TemplateEditorView: View {
    @State var template: TournamentTemplate
    @State private var validationWarnings: [ValidationWarning] = []
    @State private var sheetMode: LevelFormSheet.Mode?

    @Environment(TemplateViewModel.self) private var templateViewModel
    @Environment(\.dismiss) private var dismiss

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
                Button {
                    sheetMode = .add
                } label: {
                    Label("Добавить уровень", systemImage: "plus.circle.fill")
                }
            }
            Section {
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
                    .foregroundColor(.primary)
                }

            
            }

            // Default settings
            Section("Настройки по умолчанию") {
                HStack {
                    Text("Игроков")
                    Spacer()
                    TextField("", value: $template.defaultPlayers, format: .number)
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Стартовый стек")
                    Spacer()
                    TextField("", value: $template.defaultStartingStack, format: .number)
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .navigationTitle("Редактор шаблона")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    templateViewModel.saveAsNewTemplate(template)
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
                        template.levels.append(level)
                        for i in template.levels.indices {
                            template.levels[i].index = i + 1
                        }
                        validationWarnings = BlindValidation.validateStructure(levels: template.levels)
                    case .edit(let index):
                        guard template.levels.indices.contains(index) else { return }
                        template.levels[index] = level
                        validationWarnings = BlindValidation.validateStructure(levels: template.levels)
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

    private func validateStructure() {
        validationWarnings = BlindValidation.validateStructure(levels: template.levels)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var template = BuiltInTemplates.standardMedium
    @Previewable @State var templateViewModel = TemplateViewModel()

    NavigationStack {
        TemplateEditorView(template: template)
            .environment(templateViewModel)
    }
}
