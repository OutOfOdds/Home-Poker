import Foundation

// MARK: - Tournament Template

struct TournamentTemplate: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var levels: [BlindLevel]
    var defaultPlayers: Int?
    var defaultStartingStack: Int?
    let isBuiltIn: Bool
    let createdAt: Date
    let basedOn: String? // название шаблона, на основе которого создан

    init(
        id: UUID = UUID(),
        name: String,
        levels: [BlindLevel],
        defaultPlayers: Int? = nil,
        defaultStartingStack: Int? = nil,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        basedOn: String? = nil
    ) {
        self.id = id
        self.name = name
        self.levels = levels
        self.defaultPlayers = defaultPlayers
        self.defaultStartingStack = defaultStartingStack
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.basedOn = basedOn
    }

    /// Создаёт копию шаблона для редактирования
    func clone(newName: String? = nil) -> TournamentTemplate {
        TournamentTemplate(
            name: newName ?? "\(name) (копия)",
            levels: levels,
            defaultPlayers: defaultPlayers,
            defaultStartingStack: defaultStartingStack,
            isBuiltIn: false,
            basedOn: name
        )
    }
}
