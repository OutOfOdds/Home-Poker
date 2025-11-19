# Home Poker - iOS Poker Management Application

## 📱 О проекте

**Home Poker** - это современное iOS приложение для управления домашними покерными сессиями. Приложение поддерживает как кэш-игры (cash games), так и турниры, предоставляя полный набор инструментов для отслеживания игроков, управления банком, расчета settlements и ведения финансовой статистики.

---

## 🚀 Современные технологии Swift & SwiftUI

Проект использует **самые современные** технологии и практики разработки для iOS:

### Swift 6.0+
- **Strict Concurrency Checking** - полная безопасность при работе с многопоточностью
- **Modern Pattern Matching** - использование switch/if let/guard let с новыми возможностями
- **Value Semantics** - приоритет struct над class где возможно
- **Type Safety** - максимальное использование type system для предотвращения ошибок
- **Protocol-Oriented Programming** - протоколы как основа архитектуры

### SwiftUI (iOS 17+)
**Декларативный UI фреймворк с современными API:**

#### Observation Framework
```swift
// ✅ ИСПОЛЬЗУЕМ: @Observable (iOS 17+)
@Observable
class SessionDetailViewModel {
    var sessions: [Session] = []
    var isLoading = false
}

// ❌ НЕ ИСПОЛЬЗУЕМ: ObservableObject (старый подход)
class OldViewModel: ObservableObject {
    @Published var sessions: [Session] = []
}
```

#### Modern Navigation
```swift
// ✅ ИСПОЛЬЗУЕМ: NavigationStack (iOS 16+)
NavigationStack {
    SessionListView()
}

// ❌ НЕ ИСПОЛЬЗУЕМ: NavigationView (deprecated)
```

#### Two-Way Binding
```swift
// ✅ ИСПОЛЬЗУЕМ: @Bindable для SwiftData models
struct PlayerView: View {
    @Bindable var player: Player

    var body: some View {
        TextField("Name", text: $player.name)
    }
}
```

#### Environment для Dependency Injection
```swift
// ✅ ИСПОЛЬЗУЕМ: @Environment с custom keys
@Environment(SessionDetailViewModel.self) private var viewModel
@Environment(\.modelContext) private var modelContext
```

### SwiftData (iOS 17+)
**Современный фреймворк персистентности, замена Core Data:**

#### Декларативные модели
```swift
// ✅ ИСПОЛЬЗУЕМ: @Model макрос
@Model
final class Session {
    var startTime: Date
    var sessionTitle: String

    @Relationship(deleteRule: .cascade)
    var players: [Player] = []
}
```

#### Relationships & Cascade Rules
- **@Relationship(deleteRule: .cascade)** - автоматическое удаление связанных объектов
- **@Relationship(deleteRule: .nullify)** - обнуление ссылок при удалении
- **Inverse relationships** - автоматическая двусторонняя связь

#### Reactive Queries
```swift
// ✅ ИСПОЛЬЗУЕМ: @Query для автоматической реактивности
@Query(sort: \Session.startTime, order: .reverse)
private var sessions: [Session]
```

### Swift Concurrency
**Структурированная многопоточность:**

```swift
// ✅ ИСПОЛЬЗУЕМ: async/await
func loadData() async throws -> [Session] {
    try await sessionRepository.fetchAll()
}

// ✅ ИСПОЛЬЗУЕМ: Task для асинхронных операций
Task {
    await viewModel.loadSessions()
}

// ✅ ИСПОЛЬЗУЕМ: @MainActor для UI updates
@MainActor
func updateUI() {
    // Гарантированно выполняется в main thread
}
```

### Modern Swift Features

#### Property Wrappers
```swift
@State, @Binding, @Environment     // SwiftUI state management
@Query, @Model, @Relationship      // SwiftData
@Observable, @Bindable             // Observation framework
```

#### Result Builders
```swift
// Декларативные DSL для UI
var body: some View {
    VStack {
        Text("Title")
        Button("Action") { }
    }
}
```

#### Opaque Return Types
```swift
// ✅ ИСПОЛЬЗУЕМ: some View
var body: some View {
    VStack { }
}
```

---

## 🏗 Архитектура

### Clean Architecture + MVVM

**Слои приложения:**

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│    (Views, ViewModels, Features)    │
├─────────────────────────────────────┤
│          Domain Layer               │
│   (Models, Services, Repositories)  │
├─────────────────────────────────────┤
│           Data Layer                │
│      (SwiftData, Persistence)       │
└─────────────────────────────────────┘
```

### Dependency Flow
**View → ViewModel → Service → Repository → Data**

#### 1. View Layer (SwiftUI)
- Чистые SwiftUI views
- Только UI логика и presentation
- Navigation и sheets
- Используют ViewModels через @Environment

#### 2. ViewModel Layer (@Observable)
- Бизнес-логика presentation
- State management
- Валидация input
- Error handling
- Координация между Services

#### 3. Service Layer (Protocols)
- Бизнес-правила и domain логика
- Protocol-based для тестируемости
- Stateless где возможно
- Dependency injection через protocols

#### 4. Repository Layer
- Абстракция доступа к данным
- Инкапсулирует SwiftData операции
- CRUD operations
- Protocol-based интерфейс

#### 5. Data Layer (SwiftData)
- @Model классы с relationships
- Computed properties для derived data
- Cascade delete rules

---

## 📁 Структура проекта

```
Home Poker/
├── App/
│   └── HomePokerApp.swift          # App entry point, @main
│
├── Domain/                          # Бизнес-логика (независима от UI)
│   ├── Models/
│   │   ├── Persistence/            # SwiftData @Model классы
│   │   │   ├── Session.swift
│   │   │   ├── Player.swift
│   │   │   ├── SessionBank.swift
│   │   │   └── ...
│   │   ├── Tournament/             # Tournament domain models (Codable)
│   │   └── Transfer/               # DTOs для import/export
│   │
│   ├── Services/                   # Бизнес-логика
│   │   ├── SessionService.swift    # Protocol + Implementation
│   │   ├── SettlementService.swift
│   │   └── ...
│   │
│   ├── Repositories/               # Data access абстракция
│   │   ├── SessionsRepository.swift
│   │   └── SwiftDataSessionsRepository.swift
│   │
│   └── Utils/                      # Domain utilities
│
├── Features/                       # UI Layer (feature-based)
│   ├── Session/
│   │   ├── ViewModels/            # @Observable ViewModels
│   │   └── Views/                 # SwiftUI Views
│   │       ├── SessionDetail/
│   │       │   ├── Cash/         # Cash game views
│   │       │   ├── Tournament/   # Tournament views
│   │       │   └── Shared/       # Shared components
│   │       ├── Bank/
│   │       └── Expenses/
│   │
│   ├── SessionList/
│   │   ├── ViewModels/
│   │   └── Views/
│   │
│   ├── Settlement/
│   │   ├── ViewModels/
│   │   └── Views/
│   │
│   ├── TimerManager/
│   │   ├── ViewModels/
│   │   ├── BlindsStructure/
│   │   └── Timer/
│   │
│   ├── Settings/
│   │   └── Views/
│   │
│   └── Common/                    # Компоненты, общие для features
│       └── Components/
│
├── Shared/                        # App-wide shared code
│   ├── Components/               # Reusable UI components
│   ├── Formatters/              # MoneyFormatter, etc.
│   ├── Tips/                    # TipKit configurations
│   └── Utilities/               # Extensions, helpers
│
├── Docs/                         # Документация
│   └── TOURNAMENT_IMPLEMENTATION_PLAN.md
│
└── Resources/                    # Assets, Localizations
```

### Стандартная структура Feature

**Каждый feature следует единому паттерну:**

```
Feature/
├── ViewModels/              # Все ViewModels feature
│   └── FeatureViewModel.swift
│
└── Views/                   # Все view-компоненты
    ├── FeatureView.swift   # Главный view
    ├── Subviews/           # Вспомогательные views
    └── Sheets/             # Modal sheets
```

**Примеры:**
- `Session/ViewModels/SessionDetailViewModel.swift`
- `Session/Views/SessionDetail/Cash/CashSessionDetailView.swift`
- `Settlement/ViewModels/SettlementViewModel.swift`
- `Settlement/Views/SettlementView.swift`

---

## 💻 Стандарты кодирования

### Naming Conventions

#### Types
```swift
// ✅ PascalCase для types
struct SessionDetailView: View { }
class SessionDetailViewModel { }
protocol SessionServiceProtocol { }
enum SessionType { }
```

#### Variables & Functions
```swift
// ✅ camelCase для variables/functions
var activePlayers: [Player]
func calculateSettlement() -> [Transfer]
```

#### SwiftUI Views
```swift
// ✅ Паттерн: <Feature><Purpose>View
SessionDetailView
PlayerRow
AddPlayerSheet
BankSummaryCard

// ✅ Паттерн для subviews: <Purpose>View (не Section, не Component)
ChipsStatsView (не ChipsStatsSection)
PlayerListView
```

#### ViewModels
```swift
// ✅ Паттерн: <Feature>ViewModel
SessionDetailViewModel
SettlementViewModel
TimerViewModel
```

#### Services
```swift
// ✅ Паттерн: <Purpose>Service + Protocol
protocol SessionServiceProtocol { }
final class SessionService: SessionServiceProtocol { }
```

### Swift API Design Guidelines

#### Clarity at the point of use
```swift
// ✅ ХОРОШО: понятно, что делает
viewModel.addPlayer(name: "John")
session.calculateTotalChips()

// ❌ ПЛОХО: непонятно
viewModel.add("John")
session.calc()
```

#### Prefer methods over computed properties для сложных операций
```swift
// ✅ Computed property для простых вычислений
var totalChips: Int {
    players.reduce(0) { $0 + $1.chips }
}

// ✅ Method для сложной логики
func calculateSettlement() -> [Transfer] {
    // Сложная логика расчета
}
```

#### Omit needless words
```swift
// ✅ ХОРОШО
func remove(player: Player)

// ❌ ПЛОХО
func removePlayer(player: Player)  // "Player" избыточно в аргументе
```

### SwiftUI Conventions

#### Extract Views для читаемости
```swift
// ✅ ХОРОШО: сложная логика в отдельных views
var body: some View {
    VStack {
        headerView
        contentView
        footerView
    }
}

@ViewBuilder
private var headerView: some View {
    // Сложный header
}
```

#### Use @ViewBuilder для conditional views
```swift
@ViewBuilder
private var statusIndicator: some View {
    if session.isActive {
        ActiveBadge()
    } else {
        InactiveBadge()
    }
}
```

#### Prefer private для internal views
```swift
// ✅ Private для internal views
private var detailSection: some View { }

// ✅ Public только для reusable components
public struct ReusableCard: View { }
```

### Error Handling

```swift
// ✅ ИСПОЛЬЗУЕМ: Custom error enums с LocalizedError
enum SessionServiceError: LocalizedError {
    case playerNotFound
    case invalidAmount
    case sessionClosed

    var errorDescription: String? {
        switch self {
        case .playerNotFound: "Игрок не найден"
        case .invalidAmount: "Некорректная сумма"
        case .sessionClosed: "Сессия завершена"
        }
    }
}

// ✅ ИСПОЛЬЗУЕМ: Result type для сложных операций
func processTransaction() -> Result<Transaction, SessionServiceError> {
    // ...
}

// ✅ ИСПОЛЬЗУЕМ: throws для асинхронных операций
func loadData() async throws -> [Session] {
    // ...
}
```

### Optional Handling

```swift
// ✅ ИСПОЛЬЗУЕМ: guard let для early returns
guard let player = session.players.first(where: { $0.id == playerId }) else {
    return
}

// ✅ ИСПОЛЬЗУЕМ: if let для локального scope
if let bankAmount = session.bank?.currentBalance {
    print(bankAmount)
}

// ✅ ИСПОЛЬЗУЕМ: optional chaining
let balance = session.bank?.currentBalance

// ❌ НЕ ИСПОЛЬЗУЕМ: force unwrap (!) - только в Preview/Test коде
let player = session.players.first! // ПЛОХО
```

### Access Control

```swift
// ✅ По умолчанию internal
struct SessionDetailView: View { }

// ✅ private для implementation details
private var sortedPlayers: [Player] { }

// ✅ public только для reusable components/utilities
public struct MoneyFormatter { }

// ✅ fileprivate редко - только когда нужен доступ в extensions
```

---

## 🎯 Современные практики SwiftUI

### State Management

```swift
// ✅ @State для local view state
@State private var isExpanded = false
@State private var selectedTab = 0

// ✅ @Binding для parent-child communication
struct ChildView: View {
    @Binding var text: String
}

// ✅ @Environment для dependency injection
@Environment(SessionDetailViewModel.self) private var viewModel
@Environment(\.modelContext) private var modelContext

// ✅ @Bindable для two-way binding с @Observable objects
@Bindable var viewModel: SessionDetailViewModel
TextField("Title", text: $viewModel.sessionTitle)

// ✅ @Query для SwiftData queries
@Query(sort: \Session.startTime) private var sessions: [Session]
```

### Composition over Inheritance

```swift
// ✅ ХОРОШО: Compose views из small components
struct SessionDetailView: View {
    var body: some View {
        VStack {
            SessionHeader(session: session)
            PlayerList(players: session.players)
            SessionStats(session: session)
        }
    }
}

// ❌ ПЛОХО: Не используем inheritance в SwiftUI
class BaseView: View { } // НЕТ!
```

### PreviewProvider Best Practices

```swift
// ✅ ИСПОЛЬЗУЕМ: #Preview macro (iOS 17+)
#Preview("Active Session") {
    SessionDetailView()
        .environment(PreviewData.sessionViewModel)
        .modelContainer(PreviewData.container)
}

// ✅ ИСПОЛЬЗУЕМ: Multiple preview variants
#Preview("Empty State") {
    SessionListView()
}

#Preview("With Data") {
    SessionListView()
        .environment(PreviewData.viewModelWithData)
}

// ✅ ИСПОЛЬЗУЕМ: PreviewData helper для mock data
enum PreviewData {
    static func activeSession() -> Session { }
    static var sessionViewModel: SessionDetailViewModel { }
}
```

### Navigation Patterns

```swift
// ✅ ИСПОЛЬЗУЕМ: NavigationStack с type-safe paths
NavigationStack {
    SessionListView()
        .navigationDestination(for: Session.self) { session in
            SessionDetailView(session: session)
        }
}

// ✅ ИСПОЛЬЗУЕМ: .sheet для modals
.sheet(item: $selectedPlayer) { player in
    PlayerDetailSheet(player: player)
}

// ✅ ИСПОЛЬЗУЕМ: enum для sheet management
enum ActiveSheet: Identifiable {
    case addPlayer
    case editSession
    case cashOut(Player)

    var id: String {
        switch self {
        case .addPlayer: "addPlayer"
        case .editSession: "editSession"
        case .cashOut(let player): "cashOut-\(player.id)"
        }
    }
}

@State private var activeSheet: ActiveSheet?

.sheet(item: $activeSheet) { sheet in
    switch sheet {
    case .addPlayer: AddPlayerSheet()
    case .editSession: EditSessionSheet()
    case .cashOut(let player): PlayerCashOutSheet(player: player)
    }
}
```

### Performance Best Practices

```swift
// ✅ Equatable для избежания лишних redraws
struct PlayerRow: View, Equatable {
    let player: Player

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.player.id == rhs.player.id &&
        lhs.player.name == rhs.player.name
    }
}

// ✅ @ViewBuilder для lazy evaluation
@ViewBuilder
private func makeContent() -> some View {
    if isLoading {
        ProgressView()
    } else {
        ContentView()
    }
}
```

---

## 🔧 Domain Layer

### Services (Protocol-Driven)

**Все сервисы основаны на протоколах для тестируемости:**

```swift
// ✅ Паттерн: Protocol + Concrete Implementation
protocol SessionServiceProtocol {
    func addPlayer(to session: Session, name: String, buyIn: Int) throws
    func cashOutPlayer(_ player: Player, amount: Int) throws
    func calculateSettlement(for session: Session) -> [Transfer]
}

final class SessionService: SessionServiceProtocol {
    private let repository: SessionsRepository

    init(repository: SessionsRepository) {
        self.repository = repository
    }

    // Implementation...
}
```

**Dependency Injection через initializer:**

```swift
// ✅ В ViewModel
@Observable
final class SessionDetailViewModel {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol = SessionService()) {
        self.sessionService = sessionService
    }
}
```

### Repository Pattern

```swift
// ✅ Protocol для абстракции
protocol SessionsRepository {
    func fetchAll() throws -> [Session]
    func fetch(by id: UUID) throws -> Session?
    func save(_ session: Session) throws
    func delete(_ session: Session) throws
}

// ✅ SwiftData implementation
final class SwiftDataSessionsRepository: SessionsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
```

### Models Best Practices

```swift
// ✅ SwiftData @Model с relationships
@Model
final class Session {
    var id: UUID
    var startTime: Date
    var sessionTitle: String

    // ✅ Cascade delete для owned relationships
    @Relationship(deleteRule: .cascade)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade)
    var bank: SessionBank?

    // ✅ Computed properties для derived data
    var totalChips: Int {
        players.reduce(0) { $0 + $1.totalBuyIn }
    }

    var activePlayers: [Player] {
        players.filter { $0.inGame }
    }

    // ✅ Initializer с default значениями
    init(startTime: Date = Date(), sessionTitle: String = "") {
        self.id = UUID()
        self.startTime = startTime
        self.sessionTitle = sessionTitle
    }
}
```

---

## ✅ Что ИСПОЛЬЗОВАТЬ

### Swift & SwiftUI
- ✅ **Swift 6.0+** современный синтаксис
- ✅ **@Observable** вместо ObservableObject
- ✅ **NavigationStack** вместо NavigationView
- ✅ **async/await** для асинхронных операций
- ✅ **@Query** для SwiftData запросов
- ✅ **@Bindable** для two-way binding
- ✅ **#Preview** macro для previews
- ✅ **if let / guard let** для optionals
- ✅ **Result type** для error handling
- ✅ **Protocol-oriented** design
- ✅ **Dependency Injection** через protocols
- ✅ **Value semantics** (struct) где возможно

### Architecture
- ✅ **MVVM** с @Observable ViewModels
- ✅ **Clean Architecture** слои
- ✅ **Repository pattern** для data access
- ✅ **Service layer** для бизнес-логики
- ✅ **Feature-based** организация
- ✅ **Composition** over inheritance

### Code Style
- ✅ **Swift API Design Guidelines**
- ✅ **Meaningful names** - ясные имена
- ✅ **Small, focused functions**
- ✅ **Guard для early returns**
- ✅ **Computed properties** для простых вычислений
- ✅ **Private по умолчанию** - минимизируем scope
- ✅ **Documentation** для public API

---

## ❌ Чего ИЗБЕГАТЬ

### Устаревшие паттерны
- ❌ **ObservableObject** → используй @Observable
- ❌ **@Published** → используй @Observable properties
- ❌ **NavigationView** → используй NavigationStack
- ❌ **UIViewRepresentable** без необходимости
- ❌ **Core Data** → используй SwiftData
- ❌ **Combine** для простых задач → используй async/await

### Анти-паттерны
- ❌ **Force unwraps (!)** - только в tests/previews
- ❌ **Massive ViewModels** - разбивай на сервисы
- ❌ **God objects** - Single Responsibility
- ❌ **Global state** - используй Environment
- ❌ **Singletons** без веской причины
- ❌ **Deep inheritance** - используй composition
- ❌ **Tight coupling** - используй protocols

### Code Smells
- ❌ **Magic numbers** - используй constants
- ❌ **Nested optionals** - рефактори
- ❌ **Long parameter lists** - создай struct
- ❌ **Commented code** - удаляй
- ❌ **Inconsistent naming** - следуй conventions
- ❌ **Duplicate code** - extract & reuse

---

## 📚 Дополнительные правила

### Localization
- Все UI тексты на **русском языке**
- Использовать прямые строки (пока без локализации файлов)
- Готовность к будущей локализации

### Code Organization
- **Один тип = один файл** (кроме мелких helpers)
- **Extensions в отдельных файлах** если большие
- **Private extensions** в том же файле
- **Group по функциональности** в Xcode

### Git Practices
- **Meaningful commit messages** на русском
- **Atomic commits** - одна задача = один commit
- **Feature branches** для крупных изменений
- **Code review** перед merge

### Testing
- **Unit tests** для Services и ViewModels
- **Preview** для UI компонентов
- **PreviewData** для mock data
- **Test-friendly** архитектура (DI, protocols)

### Documentation
- **Header comments** для public API
- **Inline comments** только где нужно объяснение
- **README** в Docs/ для архитектурных решений
- **MARK:** для группировки кода

```swift
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Preview
```

---

## 🎓 Дополнительные ресурсы

### Apple Documentation
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Observation Framework](https://developer.apple.com/documentation/observation)

### Design Patterns
- Clean Architecture
- MVVM
- Repository Pattern
- Dependency Injection
- Protocol-Oriented Programming

---

## 📝 Резюме

**Home Poker** - это современное SwiftUI приложение, использующее **лучшие практики 2024-2025 года**:

- 🎯 **Swift 6.0+** с современным синтаксисом
- 🔄 **@Observable** для state management
- 💾 **SwiftData** для персистентности
- 🏗 **Clean Architecture** + **MVVM**
- 🧩 **Protocol-driven** дизайн
- 🎨 **Declarative SwiftUI** UI
- ⚡️ **async/await** для асинхронности
- 🧪 **Testable** архитектура

При работе с проектом **всегда приоритет** отдается современным технологиям и best practices.

---

*Последнее обновление: 2025-01-19*
