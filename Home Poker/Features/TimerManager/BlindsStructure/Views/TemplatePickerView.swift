import SwiftUI

struct TemplatePickerView: View {
    @Environment(TemplateViewModel.self) private var templateViewModel
    @Environment(TimerViewModel.self) private var timerViewModel

    @State private var groupIsOpen = true
    @State private var templateToEdit: TournamentTemplate?

    var body: some View {
        content
            .navigationDestination(item: $templateToEdit) { template in
                TemplateEditorView(template: template)
            }
    }

    private var content: some View {
        List {
            // Встроенные шаблоны
            DisclosureGroup("Встроенные шаблоны", isExpanded: $groupIsOpen) {
                // Тестовые шаблоны
                if !testTemplates.isEmpty {
                    Section {
                        TemplateGroupView(
                            title: "Тестовые",
                            icon: "flask.fill",
                            subtitle: "Для проверки функций",
                            templates: testTemplates,
                            templateToEdit: $templateToEdit
                        )
                    }
                }

                Section {
                    TemplateGroupView(
                        title: "Турбо (2 часа)",
                        icon: "hare.fill",
                        subtitle: "12 уровней по 10 минут",
                        templates: turboTemplates,
                        templateToEdit: $templateToEdit
                    )
                }
                Section {
                    TemplateGroupView(
                        title: "Стандарт (4 часа)",
                        icon: "figure.walk",
                        subtitle: "20 уровней по 12 минут",
                        templates: standardTemplates,
                        templateToEdit: $templateToEdit
                    )
                }
                Section {
                    TemplateGroupView(
                        title: "Глубокий стек (6 часов)",
                        icon: "tortoise.fill",
                        subtitle: "30 уровней по 12 минут",
                        templates: deepTemplates,
                        templateToEdit: $templateToEdit
                    )
                }
            }

            // Мои шаблоны
            Section {
                if templateViewModel.userTemplates.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("Пока нет своих шаблонов")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Создайте свой, отредактировав любой встроенный")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(templateViewModel.userTemplates) { template in
                        TemplateRow(
                            template: template,
                            variant: .user,
                            onStart: {
                                timerViewModel.startFromTemplate(template)
                            },
                            onEdit: {
                                templateToEdit = template
                            },
                            onDelete: {
                                templateViewModel.deleteTemplate(id: template.id)
                            }
                        )
                    }
                }

                // Кнопка создания нового шаблона
                Button {
                    // TODO: Показать выбор базового шаблона
                    print("Создать новый шаблон")
                } label: {
                    Label(
                        "Создать новый шаблон",
                        systemImage: "plus.circle.fill"
                    )
                    .font(.headline)
                }
            } header: {
                Text("Мои шаблоны")
            }
        }
        .navigationTitle("Структура")
    }

    // MARK: - Computed Properties

    private var testTemplates: [TournamentTemplate] {
        templateViewModel.builtInTemplates.filter { $0.name.contains("ТЕСТ") || $0.name.contains("🧪") }
    }

    private var turboTemplates: [TournamentTemplate] {
        templateViewModel.builtInTemplates.filter { $0.name.contains("Турбо") }
    }

    private var standardTemplates: [TournamentTemplate] {
        templateViewModel.builtInTemplates.filter {
            $0.name.contains("Стандарт")
        }
    }

    private var deepTemplates: [TournamentTemplate] {
        templateViewModel.builtInTemplates.filter {
            $0.name.contains("Глубокий")
        }
    }
}

// MARK: - Template Group View

struct TemplateGroupView: View {
    @Environment(TimerViewModel.self) private var timerViewModel

    let title: String
    let icon: String
    let subtitle: String
    let templates: [TournamentTemplate]
    
    @Binding var templateToEdit: TournamentTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок группы
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            ForEach(templates) { template in
                TemplateRow(
                    template: template,
                    variant: .builtIn,
                    onStart: {
                        timerViewModel.startFromTemplate(template)
                    },
                    onEdit: {
                        templateToEdit = template
                    },
                    onDelete: nil
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Общая ячейка шаблона

struct TemplateRow: View {
    let template: TournamentTemplate
    let variant: Variant
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

    enum Variant {
        case builtIn
        case user
    }

    var body: some View {
        switch variant {
        case .builtIn:
            builtInRow
        case .user:
            userRow
        }
    }

    private var builtInRow: some View {
        HStack(spacing: 12) {
            Text(
                template.defaultStartingStack ?? 0,
                format: .number.notation(.compactName)
            )
            .font(.subheadline)

            Line()
                .stroke(style: .init(dash: [5]))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(height: 1)

            HStack(spacing: 8) {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.leading, 8)
    }

    private var userRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)

                if let basedOn = template.basedOn {
                    Text("На основе: \(basedOn)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(template.levels.count) уровней")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)

                if let onDelete = onDelete {
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .alert("Удалить шаблон?", isPresented: $showDeleteAlert) {
                        Button("Отмена", role: .cancel) {}
                        Button("Удалить", role: .destructive) {
                            onDelete()
                        }
                    } message: {
                        Text("Шаблон '\(template.name)' будет удалён")
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var templateViewModel = TemplateViewModel()
    @Previewable @State var timerViewModel = TimerViewModel()

    return NavigationStack {
        TemplatePickerView()
            .environment(templateViewModel)
            .environment(timerViewModel)
    }
}
