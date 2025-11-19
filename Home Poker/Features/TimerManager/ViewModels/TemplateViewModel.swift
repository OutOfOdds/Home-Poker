import Foundation
import Observation
import SwiftUI

@Observable
final class TemplateViewModel {

    // MARK: - Services

    private let templateService = TemplateService()

    // MARK: - State (список шаблонов)

    var builtInTemplates: [TournamentTemplate] = []
    var userTemplates: [TournamentTemplate] = []

    // MARK: - Initialization

    init() {
        loadTemplates()
    }

    // MARK: - Public Methods (список шаблонов)

    /// Загрузить все шаблоны
    func loadTemplates() {
        builtInTemplates = templateService.getBuiltInTemplates()
        userTemplates = templateService.loadUserTemplates()
    }

    /// Удалить пользовательский шаблон
    func deleteTemplate(id: UUID) {
        do {
            try templateService.deleteTemplate(id: id)
            // TODO: После реализации удаления - перезагрузить список
            // userTemplates = templateService.loadUserTemplates()
            print("✅ Шаблон с ID \(id) будет удалён после реализации")
        } catch {
            print("❌ Ошибка удаления шаблона: \(error)")
        }
    }

    /// Сохранить отредактированный шаблон как новый пользовательский шаблон
    func saveAsNewTemplate(_ template: TournamentTemplate) {
        let newTemplate = template.clone(newName: template.name)
        userTemplates.append(newTemplate)

        do {
            try templateService.saveTemplate(newTemplate)
            print("✅ Шаблон '\(newTemplate.name)' сохранён")
        } catch {
            print("❌ Ошибка сохранения шаблона: \(error)")
        }
    }

}
