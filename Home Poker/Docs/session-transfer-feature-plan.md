# План реализации передачи сессии между организаторами

## Описание проблемы

**Сценарий использования:**
Организатор А начал вести сессию покерной игры (добавил игроков, записал транзакции buy-in/cash-out, расходы). В процессе игры ему необходимо уехать, но игра продолжается. Организатор А хочет передать управление сессией организатору Б, чтобы тот мог продолжить ведение записей.

**Текущая ситуация:**
- Все данные хранятся локально на устройстве (SwiftData)
- Нет облачной синхронизации
- Нет системы пользователей/аккаунтов
- Нет функционала экспорта/импорта сессий

**Требуемое решение:**
Простой механизм передачи сессии через файл, который можно отправить через любой мессенджер (WhatsApp, Telegram) или AirDrop.

---

## Архитектурное решение

### Выбранный подход: Экспорт/импорт через JSON-файл

**Почему этот подход:**
- ✅ Простая реализация (~500 строк кода)
- ✅ Не требует backend/сервера
- ✅ Работает офлайн
- ✅ Не требует интернет-соединения
- ✅ Полный контроль над данными (приватность)
- ✅ Работает с любым размером сессии
- ✅ Можно отправить через любой канал связи

**Принцип работы:**
1. Организатор А нажимает кнопку "Поделиться сессией" в детальном виде сессии
2. Приложение создает JSON-файл с расширением `.pokersession`
3. Открывается нативный Share Sheet iOS (AirDrop, мессенджеры, почта)
4. Организатор Б получает файл и открывает в приложении
5. Приложение импортирует сессию и создает новую локальную копию
6. Организатор Б продолжает работу с сессией

**Важно:** После передачи существует две независимые копии сессии. Синхронизация изменений между ними не предусмотрена (это базовая версия функционала).

---

## Технические детали

### Transfer DTO (Data Transfer Objects)

Поскольку SwiftData модели не являются `Codable`, необходимо создать отдельные структуры-близнецы для сериализации в JSON.

**Структура данных для передачи:**

```swift
// Основная структура сессии
struct SessionTransferDTO: Codable {
    let id: UUID
    let sessionTitle: String
    let startTime: Date
    let endTime: Date?
    let location: String
    let gameType: String // "NLHoldem" или "PLO4"
    let chipsToCashRatio: Int
    let smallBlind: Int
    let bigBlind: Int
    let ante: Int?
    let status: String // "active", "awaitingForSettlements", "finished"
    let players: [PlayerTransferDTO]
    let bank: SessionBankTransferDTO?
    let expenses: [ExpenseTransferDTO]
    let metadata: TransferMetadata

    struct TransferMetadata: Codable {
        let formatVersion: String // "1.0"
        let exportDate: Date
        let appVersion: String
    }
}

// Игрок с транзакциями
struct PlayerTransferDTO: Codable {
    let id: UUID
    let name: String
    let inGame: Bool
    let getsRakeback: Bool
    let rakeback: Int
    let transactions: [TransactionTransferDTO]
}

// Транзакция игрока (buy-in, add-on, cash-out)
struct TransactionTransferDTO: Codable {
    let id: UUID
    let timestamp: Date
    let type: String // "buyIn", "addOn", "cashOut"
    let chipAmount: Int
}

// Банк сессии
struct SessionBankTransferDTO: Codable {
    let id: UUID
    let expectedTotal: Int
    let isClosed: Bool
    let managerPlayerID: UUID? // ID игрока-менеджера
    let transactions: [SessionBankTransactionTransferDTO]
}

// Транзакция банка
struct SessionBankTransactionTransferDTO: Codable {
    let id: UUID
    let timestamp: Date
    let amount: Int
    let type: String // "deposit", "withdrawal"
    let playerID: UUID?
    let notes: String?
}

// Расход
struct ExpenseTransferDTO: Codable {
    let id: UUID
    let title: String
    let amount: Int
    let timestamp: Date
    let payerPlayerID: UUID? // ID игрока, оплатившего расход
    let paidFromRake: Bool
    let distribution: [ExpenseDistributionTransferDTO]
}

// Распределение расхода
struct ExpenseDistributionTransferDTO: Codable {
    let id: UUID
    let playerID: UUID
    let amount: Int
}
```

### Формат файла

- **Расширение:** `.pokersession`
- **MIME type:** `application/json`
- **Кодировка:** UTF-8
- **Формат дат:** ISO8601 с timezone
- **Pretty print:** Да (для читаемости при отладке)
- **Имя файла:** `{sessionTitle}_{YYYY-MM-DD}.pokersession`
  - Пример: `Домашняя_игра_2025-01-13.pokersession`

### Обработка конфликтов ID

**Проблема:** Если импортировать сессию на устройство, где уже есть сессия с таким же UUID, произойдет конфликт.

**Решение:**
1. При импорте генерируем **новые UUID** для всех объектов (Session, Player, Transaction, Bank, Expense)
2. Сохраняем маппинг старых ID → новых ID для восстановления связей
3. Восстанавливаем все связи с новыми ID (player.transactions, bank.manager, expense.payer, etc.)

Это гарантирует, что импортированная сессия будет полностью независимой копией.

---

## План реализации

### Этап 1: Создание Transfer Models

**Файл:** `Home Poker/Domain/Models/Transfer/SessionTransferDTO.swift`

**Действия:**
1. Создать папку `Transfer/` в `Domain/Models/`
2. Создать все DTO структуры с протоколом `Codable`
3. Добавить вспомогательные методы инициализации из SwiftData моделей:
   ```swift
   extension SessionTransferDTO {
       init(from session: Session, exportDate: Date, appVersion: String) {
           // Конвертация Session → SessionTransferDTO
       }
   }
   ```

**Размер:** ~200 строк кода

---

### Этап 2: Создание SessionTransferService

**Файл:** `Home Poker/Domain/Services/SessionTransferService.swift`

**Протокол:**
```swift
protocol SessionTransferService {
    func exportSession(_ session: Session) throws -> Data
    func importSession(from data: Data, into context: ModelContext) throws -> Session
}
```

**Реализация:**
```swift
final class SessionTransferServiceImpl: SessionTransferService {

    // MARK: - Export

    func exportSession(_ session: Session) throws -> Data {
        // 1. Получить версию приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // 2. Конвертировать Session → SessionTransferDTO
        let dto = SessionTransferDTO(
            from: session,
            exportDate: Date(),
            appVersion: appVersion
        )

        // 3. Сериализовать в JSON с pretty print
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(dto)
    }

    // MARK: - Import

    func importSession(from data: Data, into context: ModelContext) throws -> Session {
        // 1. Десериализовать JSON → DTO
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SessionTransferDTO.self, from: data)

        // 2. Валидировать данные
        try validateTransferData(dto)

        // 3. Создать маппинг старых ID → новых ID
        let idMapper = IDMapper()

        // 4. Создать новую Session
        let session = Session(
            sessionTitle: dto.sessionTitle,
            location: dto.location,
            gameType: GameType(rawValue: dto.gameType) ?? .nlHoldem,
            chipsToCashRatio: dto.chipsToCashRatio,
            smallBlind: dto.smallBlind,
            bigBlind: dto.bigBlind,
            ante: dto.ante
        )
        session.startTime = dto.startTime
        session.endTime = dto.endTime
        session.status = SessionStatus(rawValue: dto.status) ?? .active

        idMapper.map(oldID: dto.id, to: session.id)

        // 5. Создать игроков
        var playersMap: [UUID: Player] = [:]
        for playerDTO in dto.players {
            let player = Player(name: playerDTO.name)
            player.inGame = playerDTO.inGame
            player.getsRakeback = playerDTO.getsRakeback
            player.rakeback = playerDTO.rakeback

            idMapper.map(oldID: playerDTO.id, to: player.id)
            playersMap[playerDTO.id] = player
            session.players.append(player)

            // 5.1 Создать транзакции игрока
            for txDTO in playerDTO.transactions {
                let transaction = PlayerChipTransaction(
                    type: ChipTransactionType(rawValue: txDTO.type) ?? .buyIn,
                    chipAmount: txDTO.chipAmount,
                    player: player
                )
                transaction.timestamp = txDTO.timestamp
                player.transactions.append(transaction)
            }
        }

        // 6. Создать банк (если есть)
        if let bankDTO = dto.bank {
            let bank = SessionBank(session: session)
            bank.expectedTotal = bankDTO.expectedTotal
            bank.isClosed = bankDTO.isClosed

            // 6.1 Установить менеджера
            if let managerID = bankDTO.managerPlayerID,
               let manager = playersMap[managerID] {
                bank.manager = manager
            }

            // 6.2 Создать транзакции банка
            for txDTO in bankDTO.transactions {
                let player = txDTO.playerID.flatMap { playersMap[$0] }
                let transaction = SessionBankTransaction(
                    amount: txDTO.amount,
                    type: BankTransactionType(rawValue: txDTO.type) ?? .deposit,
                    player: player,
                    bank: bank
                )
                transaction.timestamp = txDTO.timestamp
                transaction.notes = txDTO.notes
                bank.transactions.append(transaction)
            }

            session.bank = bank
        }

        // 7. Создать расходы
        for expenseDTO in dto.expenses {
            let payer = expenseDTO.payerPlayerID.flatMap { playersMap[$0] }
            let expense = Expense(
                title: expenseDTO.title,
                amount: expenseDTO.amount,
                payer: payer,
                session: session
            )
            expense.timestamp = expenseDTO.timestamp
            expense.paidFromRake = expenseDTO.paidFromRake

            // 7.1 Создать распределение расхода
            for distDTO in expenseDTO.distribution {
                if let player = playersMap[distDTO.playerID] {
                    let distribution = ExpenseDistribution(
                        player: player,
                        amount: distDTO.amount,
                        expense: expense
                    )
                    expense.distribution.append(distribution)
                }
            }

            session.expenses.append(expense)
        }

        // 8. Сохранить в контекст
        context.insert(session)
        try context.save()

        return session
    }

    // MARK: - Validation

    private func validateTransferData(_ dto: SessionTransferDTO) throws {
        // Проверить версию формата
        guard dto.metadata.formatVersion == "1.0" else {
            throw TransferError.unsupportedFormatVersion(dto.metadata.formatVersion)
        }

        // Проверить целостность данных
        let playerIDs = Set(dto.players.map { $0.id })

        // Проверить, что manager существует среди игроков
        if let managerID = dto.bank?.managerPlayerID {
            guard playerIDs.contains(managerID) else {
                throw TransferError.invalidReference("Bank manager not found in players")
            }
        }

        // Проверить, что все payer'ы существуют
        for expense in dto.expenses {
            if let payerID = expense.payerPlayerID {
                guard playerIDs.contains(payerID) else {
                    throw TransferError.invalidReference("Expense payer not found in players")
                }
            }

            // Проверить distribution
            for dist in expense.distribution {
                guard playerIDs.contains(dist.playerID) else {
                    throw TransferError.invalidReference("Distribution player not found")
                }
            }
        }
    }
}

// MARK: - Helper Classes

private class IDMapper {
    private var mapping: [UUID: UUID] = [:]

    func map(oldID: UUID, to newID: UUID) {
        mapping[oldID] = newID
    }

    func newID(for oldID: UUID) -> UUID? {
        mapping[oldID]
    }
}

// MARK: - Errors

enum TransferError: LocalizedError {
    case unsupportedFormatVersion(String)
    case invalidReference(String)
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            return "Неподдерживаемая версия формата: \(version)"
        case .invalidReference(let message):
            return "Ошибка целостности данных: \(message)"
        case .corruptedData:
            return "Поврежденный файл сессии"
        }
    }
}
```

**Размер:** ~250 строк кода

---

### Этап 3: UI для экспорта сессии

**Файл:** `Home Poker/Features/Session/SessionDetail/SessionDetailView.swift`

**Изменения:**
1. Добавить `@State` для хранения экспортированного файла
2. Добавить кнопку "Поделиться" в toolbar
3. Использовать `ShareLink` для нативного Share Sheet

**Код:**
```swift
struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: Session

    @State private var sessionTransferFile: SessionTransferFile?
    @State private var showExportError = false
    @State private var exportError: Error?

    private let transferService: SessionTransferService = SessionTransferServiceImpl()

    var body: some View {
        // ... существующий код
        .toolbar {
            // ... существующие кнопки

            ToolbarItem(placement: .topBarTrailing) {
                if let transferFile = sessionTransferFile {
                    ShareLink(
                        item: transferFile.url,
                        preview: SharePreview(
                            "Сессия: \(session.sessionTitle)",
                            image: Image(systemName: "suit.spade.fill")
                        )
                    ) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        exportSession()
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .alert("Ошибка экспорта", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError?.localizedDescription ?? "Не удалось экспортировать сессию")
        }
    }

    private func exportSession() {
        do {
            let data = try transferService.exportSession(session)
            let filename = generateFilename(for: session)
            let url = try saveToTemporaryFile(data: data, filename: filename)
            sessionTransferFile = SessionTransferFile(url: url, filename: filename)
        } catch {
            exportError = error
            showExportError = true
        }
    }

    private func generateFilename(for session: Session) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: session.startTime)

        let sanitizedTitle = session.sessionTitle
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        return "\(sanitizedTitle)_\(dateString).pokersession"
    }

    private func saveToTemporaryFile(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
}

struct SessionTransferFile: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
}
```

**Размер изменений:** +50 строк

---

### Этап 4: UI для импорта сессии

**Файл:** `Home Poker/Features/SessionList/Views/SessionListView.swift`

**Изменения:**
1. Добавить `@State` для file importer
2. Добавить кнопку "Импорт" в toolbar
3. Обработка выбранного файла

**Код:**
```swift
struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError: Error?
    @State private var importedSession: Session?

    private let transferService: SessionTransferService = SessionTransferServiceImpl()

    var body: some View {
        NavigationStack {
            // ... существующий код списка
            .toolbar {
                // ... существующие кнопки

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Импорт", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.pokerSession],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Сессия импортирована", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                if let session = importedSession {
                    Text("Сессия \"\(session.sessionTitle)\" успешно импортирована")
                }
            }
            .alert("Ошибка импорта", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError?.localizedDescription ?? "Не удалось импортировать сессию")
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            importSession(from: fileURL)
        case .failure(let error):
            importError = error
            showImportError = true
        }
    }

    private func importSession(from url: URL) {
        do {
            // Получить доступ к файлу
            guard url.startAccessingSecurityScopedResource() else {
                throw TransferError.corruptedData
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Прочитать данные
            let data = try Data(contentsOf: url)

            // Импортировать
            let session = try transferService.importSession(from: data, into: modelContext)

            // Показать успех
            importedSession = session
            showImportSuccess = true

        } catch {
            importError = error
            showImportError = true
        }
    }
}
```

**Размер изменений:** +60 строк

---

### Этап 5: Регистрация типа файла .pokersession

**Файл:** `Home Poker/Domain/Models/Transfer/PokerSessionFileType.swift`

**Создать UTType:**
```swift
import UniformTypeIdentifiers

extension UTType {
    static var pokerSession: UTType {
        UTType(exportedAs: "com.homepoker.session")
    }
}
```

**Файл:** `Home Poker/Info.plist` (или через Xcode Target Settings)

**Добавить в Info.plist:**
```xml
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.homepoker.session</string>
        <key>UTTypeDescription</key>
        <string>Home Poker Session</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.json</string>
            <string>public.data</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>pokersession</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>application/json</string>
            </array>
        </dict>
    </dict>
</array>
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Home Poker Session</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.homepoker.session</string>
        </array>
    </dict>
</array>
```

**Размер:** +30 строк конфигурации

---

### Этап 6: Тестирование

**Файл:** `Home PokerTests/Domain/SessionTransferServiceTests.swift`

**Тесты:**
```swift
import XCTest
@testable import Home_Poker

final class SessionTransferServiceTests: XCTestCase {
    var service: SessionTransferService!

    override func setUp() {
        super.setUp()
        service = SessionTransferServiceImpl()
    }

    func testExportImportSimpleSession() throws {
        // Given: Простая сессия с 2 игроками
        let session = SessionBuilder()
            .withTitle("Test Session")
            .withPlayers(["Alice", "Bob"])
            .build()

        // When: Экспортируем и импортируем
        let data = try service.exportSession(session)
        let importedSession = try service.importSession(from: data, into: modelContext)

        // Then: Данные должны совпадать
        XCTAssertEqual(importedSession.sessionTitle, session.sessionTitle)
        XCTAssertEqual(importedSession.players.count, session.players.count)
        XCTAssertNotEqual(importedSession.id, session.id) // ID должны быть разные
    }

    func testExportImportWithBank() throws {
        // Given: Сессия с банком
        let session = SessionBuilder()
            .withBank(manager: "Alice", expectedTotal: 50000)
            .build()

        // When: Экспортируем и импортируем
        let data = try service.exportSession(session)
        let importedSession = try service.importSession(from: data, into: modelContext)

        // Then: Банк должен быть восстановлен
        XCTAssertNotNil(importedSession.bank)
        XCTAssertEqual(importedSession.bank?.expectedTotal, 50000)
        XCTAssertNotNil(importedSession.bank?.manager)
    }

    func testExportImportWithExpenses() throws {
        // Given: Сессия с расходами
        let session = SessionBuilder()
            .withExpense(title: "Еда", amount: 1000, payer: "Alice")
            .build()

        // When: Экспортируем и импортируем
        let data = try service.exportSession(session)
        let importedSession = try service.importSession(from: data, into: modelContext)

        // Then: Расходы должны быть восстановлены
        XCTAssertEqual(importedSession.expenses.count, 1)
        XCTAssertEqual(importedSession.expenses.first?.title, "Еда")
    }

    func testInvalidFormatVersionThrowsError() throws {
        // Given: JSON с неподдерживаемой версией
        let invalidJSON = """
        {
            "metadata": {
                "formatVersion": "99.0"
            }
        }
        """.data(using: .utf8)!

        // When/Then: Должна быть ошибка
        XCTAssertThrowsError(try service.importSession(from: invalidJSON, into: modelContext)) { error in
            XCTAssertTrue(error is TransferError)
        }
    }
}
```

**Размер:** ~150 строк

---

## Итоговый список файлов

### Новые файлы (создать):

1. **`Home Poker/Domain/Models/Transfer/SessionTransferDTO.swift`**
   - Все DTO структуры
   - ~200 строк

2. **`Home Poker/Domain/Models/Transfer/PokerSessionFileType.swift`**
   - UTType для .pokersession
   - ~10 строк

3. **`Home Poker/Domain/Services/SessionTransferService.swift`**
   - Протокол и реализация сервиса
   - ~250 строк

4. **`Home PokerTests/Domain/SessionTransferServiceTests.swift`**
   - Unit-тесты
   - ~150 строк

### Изменяемые файлы:

1. **`Home Poker/Features/Session/SessionDetail/SessionDetailView.swift`**
   - Добавить кнопку экспорта
   - +50 строк

2. **`Home Poker/Features/SessionList/Views/SessionListView.swift`**
   - Добавить кнопку импорта
   - +60 строк

3. **`Home Poker/Info.plist`**
   - Регистрация типа файла
   - +30 строк конфигурации

### Итого:
- **Новый код:** ~610 строк
- **Изменений:** ~140 строк
- **Всего:** ~750 строк кода

---

## Процесс использования (User Flow)

### Экспорт сессии (Организатор А):

1. Открыть детальный вид активной сессии
2. Нажать кнопку "Поделиться" в правом верхнем углу (иконка квадрата со стрелкой вверх)
3. Выбрать способ отправки:
   - **AirDrop** → выбрать устройство организатора Б
   - **WhatsApp/Telegram** → отправить файл в чат
   - **Почта** → отправить как вложение
   - **Сохранить в Файлы** → для отправки позже
4. Файл отправляется с именем типа `Домашняя_игра_2025-01-13.pokersession`

### Импорт сессии (Организатор Б):

**Вариант 1: Через файл в мессенджере**
1. Получить файл в WhatsApp/Telegram
2. Нажать на файл → "Поделиться" → "Home Poker"
3. Приложение откроется и автоматически импортирует сессию
4. Появится алерт "Сессия импортирована"
5. Сессия появится в списке сессий

**Вариант 2: Через кнопку импорта в приложении**
1. Открыть приложение Home Poker
2. На экране списка сессий нажать кнопку "Импорт" (иконка квадрата со стрелкой вниз)
3. Выбрать файл `.pokersession` из Файлов/Downloads
4. Подтвердить выбор
5. Появится алерт "Сессия импортирована"
6. Сессия появится в списке

---

## Обработка ошибок

### Возможные ошибки и их обработка:

1. **Поврежденный JSON**
   - Ошибка: "Поврежденный файл сессии"
   - Причина: Файл был изменен вручную или передан не полностью
   - Решение: Попросить отправить файл заново

2. **Неподдерживаемая версия формата**
   - Ошибка: "Неподдерживаемая версия формата: X.X"
   - Причина: Файл экспортирован из более новой версии приложения
   - Решение: Обновить приложение

3. **Нарушение целостности данных**
   - Ошибка: "Ошибка целостности данных: [описание]"
   - Причина: Ссылки на несуществующих игроков (manager, payer)
   - Решение: Переэкспортировать сессию

4. **Нет доступа к файлу**
   - Ошибка: Стандартная ошибка iOS
   - Причина: Файл удален или недоступен
   - Решение: Проверить наличие файла

---

## Ограничения и известные проблемы

### Текущие ограничения:

1. **Нет синхронизации после передачи**
   - После импорта существует две независимые копии
   - Изменения в одной копии не отражаются в другой
   - Организаторы должны договориться, кто продолжает работу

2. **Нет контроля версий**
   - Невозможно понять, какая копия "свежее"
   - Нет механизма слияния изменений

3. **Полная передача данных**
   - Нельзя экспортировать только активных игроков
   - Экспортируется вся история транзакций

4. **Отсутствие шифрования**
   - Данные передаются в открытом виде (JSON)
   - Любой может прочитать содержимое файла

### Возможные улучшения в будущем:

- ✨ Выборочный экспорт (только активные игроки, без истории)
- 🔒 Опциональное шифрование файла паролем
- 📦 Batch export (экспорт нескольких сессий)
- ☁️ Автоматический backup в iCloud Drive
- 🔄 Облачная синхронизация с conflict resolution
- 👥 Многопользовательский режим (несколько организаторов одновременно)

---

## Миграция формата (версионирование)

### Текущая версия: 1.0

При изменении структуры данных в будущих версиях приложения необходимо:

1. Увеличить версию формата (например, 1.1, 2.0)
2. Обновить `SessionTransferDTO.TransferMetadata.formatVersion`
3. Реализовать миграцию старых версий:

```swift
private func migrateIfNeeded(_ dto: SessionTransferDTO) throws -> SessionTransferDTO {
    switch dto.metadata.formatVersion {
    case "1.0":
        return dto // Текущая версия
    case "0.9":
        return try migrateFrom_0_9_to_1_0(dto)
    default:
        throw TransferError.unsupportedFormatVersion(dto.metadata.formatVersion)
    }
}
```

### Принципы обратной совместимости:

- Новые поля должны быть опциональными
- Удаление полей требует увеличения major версии (2.0)
- При импорте игнорировать неизвестные поля (Decoder.keyDecodingStrategy)

---

## Тестовые сценарии

### Ручное тестирование:

#### Тест 1: Базовая передача
1. Создать сессию на устройстве А
2. Добавить 3 игроков: Alice, Bob, Charlie
3. Записать buy-in для каждого (10,000 фишек)
4. Экспортировать сессию
5. Отправить через AirDrop на устройство Б
6. Импортировать на устройстве Б
7. Проверить: все игроки и транзакции на месте

#### Тест 2: Сессия с банком
1. Создать сессию с банком
2. Установить менеджера
3. Добавить несколько транзакций банка
4. Экспортировать → импортировать
5. Проверить: банк восстановлен, менеджер правильный

#### Тест 3: Сессия с расходами
1. Создать сессию с 3 игроками
2. Добавить расход "Еда" на 1500, оплатил Alice
3. Распределить поровну между всеми
4. Экспортировать → импортировать
5. Проверить: расход восстановлен, распределение корректное

#### Тест 4: Активная игра (реальный сценарий)
1. Начать реальную сессию на устройстве А
2. Играть 1 час: buy-ins, re-buys, один cash-out
3. Добавить расход на доставку еды
4. Экспортировать и отправить на устройство Б
5. Импортировать на устройстве Б
6. Продолжить запись транзакций
7. Проверить: все данные сохранены, можно продолжить работу

#### Тест 5: Обработка ошибок
1. Попытаться импортировать текстовый файл → должна быть ошибка
2. Вручную испортить JSON → ошибка "Поврежденный файл"
3. Импортировать файл дважды → должны создаться 2 независимые копии

---

## Альтернативные подходы (рассмотрены, но не выбраны)

### QR-код передача
**Плюсы:** Быстро, визуально, без интернета
**Минусы:** Ограничение ~2-4 KB, не подходит для больших сессий
**Вердикт:** Можно добавить в будущем как дополнительный способ для маленьких сессий

### CloudKit (iCloud)
**Плюсы:** Нативное Apple решение, автосинхронизация
**Минусы:** Только iOS, сложная миграция, требует iCloud аккаунт
**Вердикт:** Слишком сложно для MVP, можно рассмотреть позже

### Firebase/Supabase backend
**Плюсы:** Real-time sync, многопользовательский режим, backup
**Минусы:** Требует backend, затраты, сложность, нужна авторизация
**Вердикт:** Избыточно для текущей задачи, возможно в будущем

---

## Заключение

Этот план описывает простое и эффективное решение для передачи покерной сессии между организаторами через экспорт/импорт JSON-файлов.

**Основные преимущества:**
- ✅ Простая реализация (~750 строк кода)
- ✅ Не требует backend или интернета
- ✅ Работает с любым размером сессии
- ✅ Полный контроль над данными (приватность)
- ✅ Интуитивный UX (нативные iOS компоненты)

**Время реализации:** 2-3 дня разработки

**Статус:** План готов к реализации

---

_Документ создан: 2025-01-13_
_Версия: 1.0_
_Автор: Claude Code_
