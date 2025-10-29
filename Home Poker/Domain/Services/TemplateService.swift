import Foundation

protocol TemplateServiceProtocol {
    func getBuiltInTemplates() -> [TournamentTemplate]
    func loadUserTemplates() -> [TournamentTemplate]
    func saveTemplate(_ template: TournamentTemplate) throws
    func deleteTemplate(id: UUID) throws
}

struct TemplateService: TemplateServiceProtocol {

    // MARK: - Встроенные шаблоны

    func getBuiltInTemplates() -> [TournamentTemplate] {
        return BuiltInTemplates.all
    }

    // MARK: - Пользовательские шаблоны

    /// Загрузить пользовательские шаблоны
    func loadUserTemplates() -> [TournamentTemplate] {
        // TODO: Реализовать загрузку из UserDefaults или SwiftData
        return []
        /*
        // Пример реализации для будущего:
        guard let data = UserDefaults.standard.data(forKey: "userTemplates") else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([TournamentTemplate].self, from: data)) ?? []
        */
    }

    /// Сохранить пользовательский шаблон
    func saveTemplate(_ template: TournamentTemplate) throws {
        print("⚠️ [TemplateService] Сохранение шаблонов будет реализовано позже")
        print("   Шаблон '\(template.name)' НЕ сохранён")
        // TODO: Реализовать сохранение через UserDefaults или SwiftData
        /*
        // Пример реализации для будущего:
        var templates = loadUserTemplates()
        templates.append(template)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(templates) {
            UserDefaults.standard.set(data, forKey: "userTemplates")
        }
        */
    }

    /// Удалить пользовательский шаблон
    func deleteTemplate(id: UUID) throws {
        print("⚠️ [TemplateService] Удаление шаблонов будет реализовано позже")
        print("   Шаблон с ID \(id) НЕ удалён")
        // TODO: Реализовать удаление через UserDefaults или SwiftData
    }
}
