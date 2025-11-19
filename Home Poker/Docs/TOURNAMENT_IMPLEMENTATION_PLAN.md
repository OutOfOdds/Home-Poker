# План реализации турнирных сессий

## Архитектурное решение: Единая модель Session с типом

### Обоснование подхода
- Минимум изменений в существующем коде
- Переиспользование 95% логики (Settlement, банк, расходы)
- Простая миграция данных
- Один `switch` в Settlement для разделения логики расчета `netCash`

---

## Этап 1: Расширение моделей данных

### 1.1 Обновить Session.swift
**Добавить:**
- `var sessionType: SessionType = .cash` - тип сессии
- Турнирные поля (опциональные):
  - `var entryFee: Int? = nil`
  - `var startingStack: Int? = nil`
  - `var prizePoolTotal: Int? = nil`
  - `var allowReEntry: Bool = false`
  - `var reEntryDeadlineLevel: Int? = nil`
- `@Relationship var tournamentResults: [TournamentResult]? = nil`
- Extension с helper методами:
  - `var isCash: Bool`, `var isTournament: Bool`
  - `func prizeFor(player: Player) -> Int`
  - `func validate() throws`
  - Обновить computed properties (`totalChips`, `chipsInGame`) с проверкой типа

### 1.2 Создать TournamentResult.swift
```swift
@Model
final class TournamentResult {
    @Attribute(.unique) var id: UUID = UUID()
    var position: Int  // место (1, 2, 3...)
    var prize: Int     // сумма выигрыша

    @Relationship var player: Player
    @Relationship var session: Session

    init(player: Player, position: Int, prize: Int) {
        self.player = player
        self.position = position
        self.prize = prize
    }
}
```

### 1.3 Обновить PlayerChipTransaction.swift
**Добавить в TransactionType:**
```swift
enum TransactionType: String, Codable, CaseIterable {
    // Кеш-игра
    case chipBuyIn
    case chipAddOn
    case сhipCashOut

    // Турнир
    case tournamentEntry  // вход в турнир
    case reEntry          // повторный вход
    case tournamentAddOn  // турнирный add-on
}
```

### 1.4 Создать extension Player+Tournament.swift
**Добавить:**
```swift
extension Player {
    // Общая стоимость участия в турнире (все entry)
    var totalTournamentCost: Int {
        transactions
            .filter {
                $0.type == .tournamentEntry ||
                $0.type == .reEntry ||
                $0.type == .tournamentAddOn
            }
            .reduce(0) { $0 + $1.chipAmount }
    }

    // Количество входов в турнир
    var entryCount: Int {
        transactions.filter {
            $0.type == .tournamentEntry || $0.type == .reEntry
        }.count
    }
}
```

### 1.5 Создать PrizeStructure.swift
```swift
struct PrizeStructure: Codable {
    let places: [PrizePlace]
}

struct PrizePlace: Codable, Identifiable {
    let id = UUID()
    let position: Int      // 1, 2, 3...
    let percentage: Int    // % от prize pool
    var amount: Int        // рассчитанная сумма
}

// Готовые шаблоны структур
struct PrizeStructureTemplate {
    static let winnerTakesAll = PrizeStructure(places: [
        PrizePlace(position: 1, percentage: 100, amount: 0)
    ])

    static let top2 = PrizeStructure(places: [
        PrizePlace(position: 1, percentage: 70, amount: 0),
        PrizePlace(position: 2, percentage: 30, amount: 0)
    ])

    static let top3 = PrizeStructure(places: [
        PrizePlace(position: 1, percentage: 50, amount: 0),
        PrizePlace(position: 2, percentage: 30, amount: 0),
        PrizePlace(position: 3, percentage: 20, amount: 0)
    ])

    static func top10Percent(playerCount: Int) -> PrizeStructure {
        let prizePlaces = max(1, playerCount / 10)
        // Стандартное распределение для 10% ITM
        // ...
    }
}
```

---

## Этап 2: Адаптация SettlementService

### 2.1 Обновить SettlementService.swift
**В методе `calculate(for session:)`:**

**ШАГ 1 - добавить switch для расчета базового netCash:**
```swift
var balances: [PlayerBalance] = []

for player in session.players {
    let buyIn: Int
    let cashOut: Int
    let netCash: Int

    // РАЗНАЯ ЛОГИКА В ЗАВИСИМОСТИ ОТ ТИПА СЕССИИ
    switch session.sessionType {
    case .cash:
        // Существующая кеш-логика
        buyIn = player.chipBuyIn
        cashOut = player.chipCashOut
        let netChips = cashOut - buyIn
        netCash = netChips * session.chipsToCashRatio

    case .tournament:
        // Новая турнирная логика
        buyIn = player.totalTournamentCost  // все entry + re-entry + add-on
        cashOut = 0  // не используется в турнирах
        let prize = session.prizeFor(player: player)  // из tournamentResults
        netCash = prize - buyIn
    }

    balances.append(
        PlayerBalance(
            player: player,
            buyIn: buyIn,
            cashOut: cashOut,
            netChips: 0,  // не важно для турниров
            netCash: netCash,
            rakeback: 0,
            expensePaid: 0,
            expenseShare: 0
        )
    )
}

// ШАГ 2-N: ВСЁ ОСТАЛЬНОЕ БЕЗ ИЗМЕНЕНИЙ!
// - Применение рейкбека
// - Учёт расходов
// - Банковские операции
// - Распределение через банк
// - Прямые переводы
```

**Ключевой момент:** После расчета `netCash` вся логика Settlement работает ИДЕНТИЧНО для обоих типов сессий!

---

## Этап 3: Расширение SessionService

### 3.1 Добавить турнирные методы в SessionService.swift

#### Добавление игрока в турнир
```swift
func addTournamentEntry(
    name: String,
    entryFee: Int,
    to session: Session
) throws {
    guard session.isTournament else {
        throw SessionError.invalidOperationForCash
    }

    let player = Player(name: name, inGame: true)
    let transaction = PlayerChipTransaction(
        timestamp: Date(),
        type: .tournamentEntry,
        chipAmount: entryFee
    )

    player.transactions.append(transaction)
    session.players.append(player)

    // Пересчитать prize pool
    updatePrizePool(for: session)
}
```

#### Re-entry
```swift
func reEntry(player: Player, in session: Session) throws {
    guard session.isTournament else {
        throw SessionError.invalidOperationForCash
    }

    guard session.allowReEntry else {
        throw SessionError.reEntryNotAllowed
    }

    // Проверка deadline (если используется таймер)
    if let deadline = session.reEntryDeadlineLevel,
       let currentLevel = session.currentBlindLevel,
       currentLevel > deadline {
        throw SessionError.reEntryDeadlinePassed
    }

    let transaction = PlayerChipTransaction(
        timestamp: Date(),
        type: .reEntry,
        chipAmount: session.entryFee ?? 0
    )

    player.transactions.append(transaction)
    player.inGame = true

    // Пересчитать prize pool
    updatePrizePool(for: session)
}
```

#### Вылет игрока
```swift
func eliminatePlayer(
    _ player: Player,
    position: Int,
    in session: Session
) throws {
    guard session.isTournament else {
        throw SessionError.invalidOperationForCash
    }

    player.inGame = false

    // Результат будет записан при финальном расчете
}
```

#### Запись результатов турнира
```swift
func recordTournamentResults(
    _ results: [(player: Player, position: Int, prize: Int)],
    for session: Session
) throws {
    guard session.isTournament else {
        throw SessionError.invalidOperationForCash
    }

    // Валидация: все позиции уникальны
    let positions = results.map { $0.position }
    guard positions.count == Set(positions).count else {
        throw SessionError.duplicatePositions
    }

    // Валидация: сумма призов = prize pool
    let totalPrizes = results.reduce(0) { $0 + $1.prize }
    guard totalPrizes == session.prizePoolTotal else {
        throw SessionError.prizesMismatch
    }

    // Создать TournamentResult для каждого
    session.tournamentResults = results.map {
        TournamentResult(
            player: $0.player,
            position: $0.position,
            prize: $0.prize
        )
    }

    // Все игроки завершили
    session.players.forEach { $0.inGame = false }
    session.status = .awaitingForSettlements
}
```

#### Расчет и распределение призового фонда
```swift
func updatePrizePool(for session: Session) {
    guard session.isTournament,
          let entryFee = session.entryFee else { return }

    let totalEntries = session.players.reduce(0) { $0 + $1.entryCount }
    session.prizePoolTotal = totalEntries * entryFee
}

func distributePrizes(
    structure: PrizeStructure,
    totalPrize: Int
) -> [PrizePlace] {
    var places = structure.places

    for i in places.indices {
        places[i].amount = totalPrize * places[i].percentage / 100
    }

    return places
}
```

### 3.2 Добавить валидацию для турниров
```swift
extension Session {
    func validate() throws {
        switch sessionType {
        case .cash:
            guard chipsToCashRatio > 0 else {
                throw ValidationError.invalidChipsRatio
            }

        case .tournament:
            guard let entryFee = entryFee, entryFee > 0 else {
                throw ValidationError.missingEntryFee
            }
            guard let startingStack = startingStack, startingStack > 0 else {
                throw ValidationError.missingStartingStack
            }
        }
    }
}
```

---

## Этап 4: UI компоненты

### 4.1 NewSessionSheet.swift - обновить
**Добавить выбор типа сессии:**
```swift
Form {
    Section("Тип сессии") {
        Picker("Формат", selection: $sessionType) {
            Text("Кеш-игра").tag(SessionType.cash)
            Text("Турнир").tag(SessionType.tournament)
        }
        .pickerStyle(.segmented)
    }

    Section("Основная информация") {
        TextField("Название сессии", text: $sessionTitle)
        DatePicker("Дата и время", selection: $startTime)
        TextField("Место", text: $location)
        Picker("Тип игры", selection: $gameType) {
            ForEach(GameType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
    }

    // Условные секции в зависимости от типа
    if sessionType == .cash {
        Section("Параметры кеш-игры") {
            TextField("1 фишка = X рублей", value: $chipsToCashRatio)
            TextField("Малый блайнд", value: $smallBlind)
            TextField("Большой блайнд", value: $bigBlind)
            TextField("Анте", value: $ante)
        }
    } else {
        Section("Параметры турнира") {
            TextField("Entry Fee", value: $entryFee)
            TextField("Starting Stack", value: $startingStack)

            Toggle("Разрешить Re-entry", isOn: $allowReEntry)

            if allowReEntry {
                Stepper("До уровня: \(reEntryDeadlineLevel)",
                        value: $reEntryDeadlineLevel,
                        in: 1...20)
            }
        }
    }
}
```

### 4.2 Создать TournamentResultSheet.swift
**Для ввода результатов турнира:**
```swift
struct TournamentResultSheet: View {
    @Environment(\.modelContext) private var context
    let session: Session

    @State private var playerPositions: [UUID: Int] = [:]
    @State private var prizeStructure: PrizeStructure = .top3
    @State private var calculatedPrizes: [PrizePlace] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Структура призов") {
                    Picker("Шаблон", selection: $prizeStructure) {
                        Text("Winner Takes All").tag(PrizeStructureTemplate.winnerTakesAll)
                        Text("Top 2").tag(PrizeStructureTemplate.top2)
                        Text("Top 3").tag(PrizeStructureTemplate.top3)
                    }

                    ForEach(calculatedPrizes) { place in
                        HStack {
                            Text("\(place.position) место (\(place.percentage)%)")
                            Spacer()
                            Text(place.amount.asCurrency())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section("Места игроков") {
                    ForEach(session.players) { player in
                        HStack {
                            Text(player.name)
                            Spacer()
                            Picker("Место", selection: binding(for: player)) {
                                ForEach(1...session.players.count, id: \.self) { pos in
                                    Text("#\(pos)").tag(pos)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Prize Pool:")
                        Spacer()
                        Text((session.prizePoolTotal ?? 0).asCurrency())
                            .bold()
                    }
                }
            }
            .navigationTitle("Результаты турнира")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveResults()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                calculatePrizes()
            }
            .onChange(of: prizeStructure) {
                calculatePrizes()
            }
        }
    }

    private func calculatePrizes() {
        let totalPrize = session.prizePoolTotal ?? 0
        calculatedPrizes = SessionService()
            .distributePrizes(structure: prizeStructure, totalPrize: totalPrize)
    }

    private func saveResults() {
        // Создать массив результатов
        let results: [(Player, Int, Int)] = session.players.compactMap { player in
            guard let position = playerPositions[player.id],
                  let prizePlace = calculatedPrizes.first(where: { $0.position == position }) else {
                return nil
            }
            return (player, position, prizePlace.amount)
        }

        // Сохранить через сервис
        let service = SessionService()
        try? service.recordTournamentResults(results, for: session)

        dismiss()
    }

    private var canSave: Bool {
        // Все игроки должны иметь уникальные места
        let positions = playerPositions.values
        return positions.count == session.players.count &&
               positions.count == Set(positions).count
    }
}
```

### 4.3 Создать PrizeStructureEditorView.swift
**Для создания кастомной структуры:**
```swift
struct PrizeStructureEditorView: View {
    @Binding var structure: PrizeStructure
    @State private var places: [EditablePlace] = []

    var body: some View {
        Form {
            Section {
                Button("Добавить место") {
                    places.append(EditablePlace(position: places.count + 1, percentage: 0))
                }
            }

            Section("Призовые места") {
                ForEach(places) { place in
                    HStack {
                        Text("\(place.position) место")
                        Spacer()
                        TextField("%", value: place.$percentage)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("%")
                    }
                }
                .onDelete { indexSet in
                    places.remove(atOffsets: indexSet)
                }
            }

            Section {
                HStack {
                    Text("Всего:")
                    Spacer()
                    Text("\(totalPercentage)%")
                        .foregroundStyle(totalPercentage == 100 ? .green : .red)
                }
            }
            footer: {
                if totalPercentage != 100 {
                    Text("Сумма должна быть 100%")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Структура призов")
    }

    private var totalPercentage: Int {
        places.reduce(0) { $0 + $1.percentage }
    }
}
```

### 4.4 SessionDetailView.swift - адаптировать
**Условное отображение:**
```swift
var body: some View {
    List {
        // Сегмент только для кеш-игр
        if session.isCash {
            Picker("", selection: $selectedTab) {
                Text("Инфо").tag(Tab.info)
                Text("Фишки").tag(Tab.chips)
            }
            .pickerStyle(.segmented)

            if selectedTab == .info {
                SessionInfoSummary(session: session)
            } else {
                ChipsStatsSection(session: session)
            }
        } else {
            // Для турниров - только инфо + турнирная статистика
            TournamentInfoSummary(session: session)
            TournamentStatsSection(session: session)
        }

        // Список игроков (адаптированный)
        PlayerListSection(session: session)

        // Расходы (общие)
        ExpensesSection(session: session)
    }
    .toolbar {
        // Разные кнопки в зависимости от типа
        if session.isCash {
            Button("Добавить игрока") {
                showingAddPlayerSheet = true
            }
        } else {
            Button("Добавить участника") {
                showingAddEntrySheet = true
            }

            if allPlayersEliminated {
                Button("Завершить турнир") {
                    showingTournamentResultSheet = true
                }
            }
        }
    }
}
```

### 4.5 PlayerRow.swift - адаптировать
**Разные действия для разных типов:**
```swift
var body: some View {
    VStack(alignment: .leading) {
        HStack {
            Text(player.name)
                .font(.headline)

            Spacer()

            if session.isTournament {
                // Показать количество входов
                if player.entryCount > 1 {
                    Text("×\(player.entryCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .background(.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }

        // Статистика
        if session.isCash {
            // Существующая кеш-статистика
            Text("Закуплено: \(player.chipBuyIn)")
            if !player.inGame {
                Text("Выведено: \(player.chipCashOut)")
                Text("Результат: \(player.chipProfit)")
                    .foregroundStyle(player.chipProfit >= 0 ? .green : .red)
            }
        } else {
            // Турнирная статистика
            Text("Вложено: \(player.totalTournamentCost.asCurrency())")
            if let result = session.tournamentResults?.first(where: { $0.player.id == player.id }) {
                Text("Место: #\(result.position)")
                if result.prize > 0 {
                    Text("Приз: \(result.prize.asCurrency())")
                        .foregroundStyle(.green)
                }
            } else if !player.inGame {
                Text("Выбыл")
                    .foregroundStyle(.secondary)
            }
        }

        // Кнопки действий
        HStack {
            if session.isCash {
                if player.inGame {
                    Button("Докупка") { showingAddOnSheet = true }
                    Button("Завершить") { showingCashOutSheet = true }
                } else {
                    Button("Вернуть в игру") { showingRebuySheet = true }
                }
            } else {
                if player.inGame && session.allowReEntry {
                    Button("Re-entry") {
                        performReEntry()
                    }
                    .disabled(!canReEntry)
                }

                if player.inGame {
                    Button("Выбыл") {
                        eliminatePlayer()
                    }
                }
            }
        }
    }
}
```

### 4.6 Создать TournamentStatsSection.swift
**Статистика турнира:**
```swift
struct TournamentStatsSection: View {
    let session: Session

    var body: some View {
        Section("Статистика турнира") {
            HStack {
                Text("Участников:")
                Spacer()
                Text("\(session.players.count)")
            }

            HStack {
                Text("Всего входов:")
                Spacer()
                Text("\(totalEntries)")
            }

            HStack {
                Text("Re-entries:")
                Spacer()
                Text("\(reEntryCount)")
            }

            HStack {
                Text("Prize Pool:")
                Spacer()
                Text((session.prizePoolTotal ?? 0).asCurrency())
                    .bold()
                    .foregroundStyle(.green)
            }

            HStack {
                Text("В игре:")
                Spacer()
                Text("\(activePlayers)")
            }
        }
    }

    private var totalEntries: Int {
        session.players.reduce(0) { $0 + $1.entryCount }
    }

    private var reEntryCount: Int {
        totalEntries - session.players.count
    }

    private var activePlayers: Int {
        session.players.filter { $0.inGame }.count
    }
}
```

---

## Этап 5: Интеграция с таймером (опционально)

### 5.1 Расширить Session для таймера
```swift
// В Session.swift добавить:
var useTimer: Bool = false
var blindLevels: [BlindLevel]? = nil
var currentBlindLevel: Int? = nil
```

### 5.2 Связать с TimerView
- При создании турнира - опция "Использовать таймер блайндов"
- Выбор blind structure template из существующих
- Сохранение выбранной структуры в сессию
- SessionTimerService отслеживает currentBlindLevel

### 5.3 Re-entry deadline по уровню
```swift
var canReEntry: Bool {
    guard session.isTournament && session.allowReEntry else { return false }

    if let deadline = session.reEntryDeadlineLevel,
       let current = session.currentBlindLevel {
        return current <= deadline
    }

    return true
}
```

---

## Этап 6: Миграция данных

### 6.1 Создать новую схему
```swift
// В отдельном файле SchemaVersioning.swift

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Session.self, Player.self, PlayerChipTransaction.self,
         SessionBank.self, SessionBankTransaction.self,
         Expense.self, ExpenseDistribution.self]
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Session.self, Player.self, PlayerChipTransaction.self,
         SessionBank.self, SessionBankTransaction.self,
         Expense.self, ExpenseDistribution.self,
         TournamentResult.self]  // Добавлена новая модель
    }
}
```

### 6.2 Создать план миграции
```swift
struct MigrationPlanV1toV2: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            print("Начало миграции на версию 2.0...")
        },
        didMigrate: { context in
            // Установить sessionType = .cash для всех существующих сессий
            let descriptor = FetchDescriptor<Session>()
            let sessions = try context.fetch(descriptor)

            for session in sessions {
                session.sessionType = .cash
            }

            try context.save()
            print("Миграция завершена. Обновлено \(sessions.count) сессий")
        }
    )
}
```

### 6.3 Обновить ModelContainer
```swift
// В App.swift
import SwiftData

@main
struct HomePokerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Session.self, Player.self, TournamentResult.self,
                migrationPlan: MigrationPlanV1toV2.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

---

## Этап 7: Тестирование

### 7.1 Обновить SettlementServiceTests.swift
**Добавить тесты для турниров:**

```swift
@Test("Simple tournament: 10 players, winner takes all")
func testSimpleTournament_WinnerTakesAll() {
    // Setup
    let session = createTournamentSession(
        players: ["Alice", "Bob", "Charlie"],
        entryFee: 1000
    )

    // Record results
    recordResult(session, player: "Alice", position: 1, prize: 3000)
    recordResult(session, player: "Bob", position: 2, prize: 0)
    recordResult(session, player: "Charlie", position: 3, prize: 0)

    // Calculate
    let result = service.calculate(for: session)

    // Verify
    let alice = result.balances.first { $0.player.name == "Alice" }
    #expect(alice?.netCash == 2000)  // 3000 prize - 1000 entry

    let bob = result.balances.first { $0.player.name == "Bob" }
    #expect(bob?.netCash == -1000)  // 0 prize - 1000 entry
}

@Test("Tournament with re-entries")
func testTournamentWithReEntries() {
    let session = createTournamentSession(
        players: ["Alice", "Bob"],
        entryFee: 1000,
        allowReEntry: true
    )

    // Bob делает re-entry
    reEntry(session, player: "Bob")

    // Prize pool должен обновиться: 3 × 1000 = 3000
    #expect(session.prizePoolTotal == 3000)

    // Bob вложил 2000 (entry + re-entry)
    let bob = session.players.first { $0.name == "Bob" }
    #expect(bob?.totalTournamentCost == 2000)

    // Alice выигрывает всё
    recordResult(session, player: "Alice", position: 1, prize: 3000)
    recordResult(session, player: "Bob", position: 2, prize: 0)

    let result = service.calculate(for: session)

    let aliceBalance = result.balances.first { $0.player.name == "Alice" }
    #expect(aliceBalance?.netCash == 2000)  // 3000 - 1000

    let bobBalance = result.balances.first { $0.player.name == "Bob" }
    #expect(bobBalance?.netCash == -2000)  // 0 - 2000
}

@Test("Tournament with expenses from prize pool")
func testTournamentWithExpenses() {
    let session = createTournamentSession(
        players: ["Alice", "Bob", "Charlie"],
        entryFee: 1000
    )

    // Добавить расход (оплата аренды)
    addExpense(session, amount: 600, payer: nil)
    distributeExpense(session, distributions: [
        ("Alice", 200),
        ("Bob", 200),
        ("Charlie", 200)
    ])

    // Результаты (top 2 paid: 70%/30%)
    recordResult(session, player: "Alice", position: 1, prize: 2100)  // 70% from 3000
    recordResult(session, player: "Bob", position: 2, prize: 900)     // 30% from 3000
    recordResult(session, player: "Charlie", position: 3, prize: 0)

    let result = service.calculate(for: session)

    // Alice: 2100 prize - 1000 entry - 200 expense share = +900
    let alice = result.balances.first { $0.player.name == "Alice" }
    #expect(alice?.netCash == 900)

    // Bob: 900 prize - 1000 entry - 200 expense share = -300
    let bob = result.balances.first { $0.player.name == "Bob" }
    #expect(bob?.netCash == -300)

    // Charlie: 0 prize - 1000 entry - 200 expense share = -1200
    let charlie = result.balances.first { $0.player.name == "Charlie" }
    #expect(charlie?.netCash == -1200)
}
```

### 7.2 Создать TournamentServiceTests.swift
```swift
@Suite("Tournament Service Tests")
struct TournamentServiceTests {
    let service = SessionService()

    @Test("Create tournament session")
    func testCreateTournament() {
        let input = NewTournamentInput(
            title: "Friday MTT",
            startTime: Date(),
            location: "Home",
            gameType: .NLHoldem,
            entryFee: 1000,
            startingStack: 10000,
            allowReEntry: true
        )

        let session = try #require(service.createTournament(from: input))

        #expect(session.sessionType == .tournament)
        #expect(session.entryFee == 1000)
        #expect(session.startingStack == 10000)
        #expect(session.allowReEntry == true)
    }

    @Test("Add tournament entry")
    func testAddTournamentEntry() throws {
        let session = createTestTournament()

        try service.addTournamentEntry(
            name: "Alice",
            entryFee: 1000,
            to: session
        )

        #expect(session.players.count == 1)
        #expect(session.prizePoolTotal == 1000)

        let alice = session.players.first
        #expect(alice?.name == "Alice")
        #expect(alice?.totalTournamentCost == 1000)
    }

    @Test("Re-entry updates prize pool")
    func testReEntryUpdatesPrizePool() throws {
        let session = createTestTournament(allowReEntry: true)

        try service.addTournamentEntry(name: "Alice", entryFee: 1000, to: session)
        let alice = session.players.first!

        try service.reEntry(player: alice, in: session)

        #expect(alice.entryCount == 2)
        #expect(session.prizePoolTotal == 2000)
    }

    @Test("Cannot re-entry when not allowed")
    func testReEntryNotAllowed() throws {
        let session = createTestTournament(allowReEntry: false)

        try service.addTournamentEntry(name: "Alice", entryFee: 1000, to: session)
        let alice = session.players.first!

        #expect(throws: SessionError.reEntryNotAllowed) {
            try service.reEntry(player: alice, in: session)
        }
    }

    @Test("Record tournament results")
    func testRecordResults() throws {
        let session = createTestTournament()

        try service.addTournamentEntry(name: "Alice", entryFee: 1000, to: session)
        try service.addTournamentEntry(name: "Bob", entryFee: 1000, to: session)

        let alice = session.players.first { $0.name == "Alice" }!
        let bob = session.players.first { $0.name == "Bob" }!

        try service.recordTournamentResults([
            (alice, 1, 1400),
            (bob, 2, 600)
        ], for: session)

        #expect(session.tournamentResults?.count == 2)
        #expect(session.status == .awaitingForSettlements)
        #expect(alice.inGame == false)
        #expect(bob.inGame == false)
    }
}
```

---

## Приоритеты для MVP

### Must Have (минимальный турнир):
1. ✅ Расширение Session модели с типом
2. ✅ Модель TournamentResult
3. ✅ Новые типы транзакций (tournamentEntry, reEntry)
4. ✅ Адаптация Settlement с switch
5. ✅ SessionService турнирные методы
6. ✅ NewSessionSheet с выбором типа
7. ✅ TournamentResultSheet
8. ✅ Базовые prize templates (WTA, Top 2, Top 3)
9. ✅ Миграция данных
10. ✅ Базовые тесты

### Should Have:
11. Re-entry функционал
12. Tournament add-on
13. Custom prize structure editor
14. TournamentStatsSection
15. Интеграция с таймером
16. Полный набор тестов

### Nice to Have:
17. Bounty system
18. ICM calculator
19. Deal-making tool
20. Турнирная статистика по игрокам (история)
21. Экспорт результатов турнира

---

## Примерная трудоемкость

### MVP (Must Have):
- **Модели (1.1-1.4):** 1 день
- **Settlement (2.1):** 0.5 дня
- **SessionService базовый (3.1 частично):** 1 день
- **UI базовый (4.1, 4.2, 4.4 частично):** 2-3 дня
- **Миграция (6):** 0.5 дня
- **Тестирование (7.1 частично):** 1 день

**Итого MVP:** ~6-7 дней

### Полная версия (Should Have):
- **PrizeStructure (1.5):** 0.5 дня
- **SessionService полный (3.1 полностью):** 1 день
- **UI полный (4.2-4.6):** 3-4 дня
- **Интеграция с таймером (5):** 2 дня
- **Полное тестирование (7):** 2 дня

**Итого полная версия:** ~15-18 дней

---

## Ключевые принципы реализации

1. **Минимум изменений** - используем существующую архитектуру максимально
2. **Switch вместо полиморфизма** - простота важнее элегантности
3. **Переиспользование логики** - Settlement, банк, расходы работают одинаково
4. **Опциональные поля** - не страшно, зато одна модель и простая миграция
5. **Валидация на уровне сервисов** - защита от неправильного использования полей
6. **Тестирование** - каждая фича покрывается тестами
7. **Постепенное развитие** - сначала MVP, потом расширение

---

## Потенциальные проблемы и решения

### Проблема 1: Опциональные поля могут быть nil
**Решение:**
- Computed properties с guard для безопасного доступа
- Валидация при создании/редактировании сессии
- Extension методы типа `requireEntryFee()` с throws

### Проблема 2: UI может сломаться при неправильном типе
**Решение:**
- Всегда проверять `session.isCash` / `session.isTournament`
- Условные view через `if session.isTournament { ... }`
- Disabled состояния для неприменимых действий

### Проблема 3: Settlement может запутаться в типах
**Решение:**
- Четкий switch в начале метода
- Отдельные переменные `buyIn`, `cashOut`, `netCash` для каждого случая
- Комментарии в коде о различиях

### Проблема 4: Миграция может не сработать
**Решение:**
- Тестирование миграции на тестовых данных
- Backup базы перед обновлением
- Логирование процесса миграции
- Fallback значения для новых полей

---

## Дальнейшее развитие

### После базовой реализации можно добавить:

1. **Sit & Go турниры** - фиксированное количество игроков, начало при заполнении
2. **Multi-table tournaments** - несколько столов, объединение при выбывании
3. **Satellite tournaments** - призы в виде билетов на другие турниры
4. **Spin & Go** - случайный призовой фонд
5. **Knockout/Bounty** - награда за выбивание игрока
6. **Turbo/Hyper-turbo** - ускоренная структура блайндов
7. **Freezeout vs Re-entry** - разные форматы
8. **Late registration** - опоздавшие входы
9. **Турнирная статистика** - ROI, ITM%, средние позиции
10. **Экспорт в PokerTracker/HM** - для анализа

---

## Контрольный чеклист перед запуском

- [ ] Все модели обновлены и скомпилированы
- [ ] Миграция данных протестирована
- [ ] Settlement работает для обоих типов сессий
- [ ] UI адаптирован под оба типа
- [ ] Валидация работает корректно
- [ ] Написаны и проходят unit-тесты
- [ ] Протестировано создание турнира end-to-end
- [ ] Протестирован settlement для турнира
- [ ] Проверена обратная совместимость с кеш-играми
- [ ] Документация обновлена
- [ ] Код review пройден
- [ ] Ready for production!

---

## Заключение

Данный план описывает пошаговую реализацию турнирных сессий с минимальными изменениями в существующей кодовой базе. Ключевая идея - **переиспользование** максимально возможного количества логики через добавление типа сессии и условного ветвления только там, где логика действительно различается (расчет `netCash` в Settlement).

Архитектура остается чистой, тесты покрывают новый функционал, миграция данных безопасна, а пользовательский опыт будет последовательным между кеш-играми и турнирами.
