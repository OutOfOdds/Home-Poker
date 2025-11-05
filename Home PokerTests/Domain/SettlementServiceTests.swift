//
//  SettlementServiceTests.swift
//  Home PokerTests
//
//  Тесты для SettlementService - расчёт балансов и переводов
//

import Testing
import Foundation
@testable import Home_Poker

@Suite("Settlement Service Tests")
struct SettlementServiceTests {
    let service = SettlementService()

    // MARK: - Basic P2P Tests (без банка)

    @Suite("Basic P2P Settlement")
    struct BasicP2PTests {
        let service = SettlementService()

        @Test("Simple two player settlement - one winner, one loser")
        func simpleTwoPlayerSettlement() {
            // Given: Alice выиграла 50₽, Bob проиграл 50₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)
                .addPlayer("Bob", buyIn: 100, cashOut: 50)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Bob должен отдать Alice 50₽
            assertBalance(result, player: "Alice", netCash: 50)
            assertBalance(result, player: "Bob", netCash: -50)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 50)
        }

        @Test("Multiple winners - one loser pays two winners")
        func multipleWinners() {
            // Given: Alice +60₽, Bob +40₽, Charlie -100₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 160)
                .addPlayer("Bob", buyIn: 100, cashOut: 140)
                .addPlayer("Charlie", buyIn: 100, cashOut: 0)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Charlie платит обоим (жадный алгоритм: сначала большему)
            assertBalance(result, player: "Alice", netCash: 60)
            assertBalance(result, player: "Bob", netCash: 40)
            assertBalance(result, player: "Charlie", netCash: -100)
            assertPlayerTransferCount(result, count: 2)
            assertPlayerTransfer(result, from: "Charlie", to: "Alice", amount: 60)
            assertPlayerTransfer(result, from: "Charlie", to: "Bob", amount: 40)
        }

        @Test("Multiple losers - two losers pay one winner")
        func multipleLosers() {
            // Given: Alice +100₽, Bob -60₽, Charlie -40₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 200)
                .addPlayer("Bob", buyIn: 100, cashOut: 40)
                .addPlayer("Charlie", buyIn: 100, cashOut: 60)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Оба должника платят Alice (жадный алгоритм)
            assertBalance(result, player: "Alice", netCash: 100)
            assertBalance(result, player: "Bob", netCash: -60)
            assertBalance(result, player: "Charlie", netCash: -40)
            assertPlayerTransferCount(result, count: 2)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 60)
            assertPlayerTransfer(result, from: "Charlie", to: "Alice", amount: 40)
        }

        @Test("Balanced game - everyone breaks even")
        func balancedGame() {
            // Given: Все игроки вышли с тем же количеством
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 100)
                .addPlayer("Bob", buyIn: 100, cashOut: 100)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Никаких переводов не требуется
            assertBalance(result, player: "Alice", netCash: 0)
            assertBalance(result, player: "Bob", netCash: 0)
            assertNoPlayerTransfers(result)
        }

        @Test("Chips to rubles conversion - verify ratio is applied")
        func chipsToRublesConversion() {
            // Given: 10 фишек = 1 рубль, Alice выиграла 500 фишек
            let session = SessionBuilder()
                .withChipRatio(10)
                .addPlayer("Alice", buyIn: 1000, cashOut: 1500)  // +500 фишек
                .addPlayer("Bob", buyIn: 1000, cashOut: 500)     // -500 фишек
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Переводы должны быть в рублях (500 фишек × 10 = 5000₽)
            assertBalance(result, player: "Alice", netCash: 5000)
            assertBalance(result, player: "Bob", netCash: -5000)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 5000)
        }
    }

    // MARK: - Bank Logic Tests

    @Suite("Bank Settlement Logic")
    struct BankLogicTests {
        let service = SettlementService()

        @Test("🐛 BUG FIX: Withdrawal accounting - winner withdraws from bank")
        func withdrawalAccounting() {
            // Given: Alice выиграла 80₽, получила из банка 50₽
            // Важно: withdrawal должен УМЕНЬШИТЬ то, что ей ещё должны
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 180)  // +80
                .addPlayer("Bob", buyIn: 100, cashOut: 20)     // -80
                .withBank()
                .addBankWithdrawal(player: "Alice", amount: 50)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Alice уже получила 50₽, осталось получить только 30₽
            // netContribution = 0 - 50 = -50
            // adjustedWin = 80 + (-50) = 30
            assertBalance(result, player: "Alice", netCash: 80)
            assertNoBankTransfers(result)  // Выдача уже была
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 30)
        }

        @Test("🐛 BUG FIX: Partial deposit - loser deposits partial amount")
        func partialDeposit() {
            // Given: Bob проиграл 100₽, внёс в банк 60₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 200)  // +100
                .addPlayer("Bob", buyIn: 100, cashOut: 0)      // -100
                .withBank()
                .addBankDeposit(player: "Bob", amount: 60)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Депозит 60₽ идёт Alice через банк, остальные 40₽ - прямой перевод
            // netContribution Bob = 60 - 0 = 60
            // adjustedDebt Bob = 100 - 60 = 40
            // adjustedWin Alice = 100 + 0 = 100
            assertBalance(result, player: "Alice", netCash: 100)
            assertBalance(result, player: "Bob", netCash: -100)
            assertBankTransferCount(result, count: 1)
            assertBankTransfer(result, to: "Alice", amount: 60)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 40)
        }

        @Test("🐛 BUG FIX: Overpayment refund - loser deposits more than owed")
        func overpaymentRefund() {
            // Given: Bob проиграл 50₽, но внёс 100₽ в банк
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)  // +50
                .addPlayer("Bob", buyIn: 100, cashOut: 50)     // -50
                .withBank()
                .addBankDeposit(player: "Bob", amount: 100)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Alice получает 50₽ из банка, Bob получает обратно 50₽ (переплата)
            // netContribution Bob = 100 - 0 = 100
            // adjustedDebt Bob = 50 - 100 = -50 (отрицательный = банк должен ему)
            assertBalance(result, player: "Alice", netCash: 50)
            assertBalance(result, player: "Bob", netCash: -50)
            assertBankTransferCount(result, count: 2)
            assertBankTransfer(result, to: "Alice", amount: 50)
            assertBankTransfer(result, to: "Bob", amount: 50)
            assertNoPlayerTransfers(result)
        }

        @Test("Simple bank deposit - loser deposits exact amount")
        func simpleBankDeposit() {
            // Given: Bob проиграл 80₽ и внёс ровно 80₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 180)
                .addPlayer("Bob", buyIn: 100, cashOut: 20)
                .withBank()
                .addBankDeposit(player: "Bob", amount: 80)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Все переводы идут через банк, прямых переводов нет
            assertBankTransferCount(result, count: 1)
            assertBankTransfer(result, to: "Alice", amount: 80)
            assertNoPlayerTransfers(result)
        }

        @Test("Multiple players with bank - complex scenario")
        func multiplePlayersWithBank() {
            // Given: 3 игрока, частичные депозиты и выдачи
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 170)   // +70
                .addPlayer("Bob", buyIn: 100, cashOut: 30)      // -70
                .addPlayer("Charlie", buyIn: 100, cashOut: 100) // 0
                .withBank()
                .addBankDeposit(player: "Bob", amount: 50)      // Bob внёс 50₽
                .addBankWithdrawal(player: "Alice", amount: 30) // Alice получила 30₽
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then:
            // Alice: выигрыш 70, уже получила 30 → нужно ещё 40
            // Bob: проигрыш 70, внёс 50 → должен ещё 20
            // Charlie: в нуле
            // Банк передаёт 50₽ Alice (из депозита Bob)
            // Bob платит Alice напрямую: 70 - 50 (покрыто банком) = 20₽
            assertBalance(result, player: "Alice", netCash: 70)
            assertBalance(result, player: "Bob", netCash: -70)
            assertBalance(result, player: "Charlie", netCash: 0)
            assertBankTransferCount(result, count: 1)
            assertBankTransfer(result, to: "Alice", amount: 20)  // 50 - 30 уже выданных
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 20)
        }

        @Test("No bank fallback - session without bank")
        func noBankFallback() {
            // Given: Сессия БЕЗ банка
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)
                .addPlayer("Bob", buyIn: 100, cashOut: 50)
                .build()

            // When: Вызываем calculateWithBank
            let result = service.calculateWithBank(for: session)

            // Then: Работает как обычный calculate (fallback)
            assertBalance(result, player: "Alice", netCash: 50)
            assertBalance(result, player: "Bob", netCash: -50)
            assertNoBankTransfers(result)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 50)
        }

        @Test("Empty bank - bank exists but no transactions")
        func emptyBank() {
            // Given: Банк создан, но транзакций нет
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)
                .addPlayer("Bob", buyIn: 100, cashOut: 50)
                .withBank()
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Как будто банка нет
            assertBalance(result, player: "Alice", netCash: 50)
            assertBalance(result, player: "Bob", netCash: -50)
            assertNoBankTransfers(result)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 50)
        }

        @Test("Winner deposits to bank - should get it back")
        func winnerDepositsToBank() {
            // Given: Alice выиграла 50₽, но почему-то внесла 20₽ в банк
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)  // +50
                .addPlayer("Bob", buyIn: 100, cashOut: 50)     // -50
                .withBank()
                .addBankDeposit(player: "Alice", amount: 20)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Alice получает свой выигрыш 50₽ + депозит 20₽ = 70₽ всего
            // netContribution Alice = 20 - 0 = 20
            // adjustedWin Alice = 50 + 20 = 70
            assertBalance(result, player: "Alice", netCash: 50)
            assertBankTransferCount(result, count: 1)
            assertBankTransfer(result, to: "Alice", amount: 70)
            assertNoPlayerTransfers(result)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        let service = SettlementService()

        @Test("All players break even")
        func allPlayersBreakEven() {
            // Given: Все игроки в нуле
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 100)
                .addPlayer("Bob", buyIn: 100, cashOut: 100)
                .addPlayer("Charlie", buyIn: 100, cashOut: 100)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Нет переводов
            assertBalance(result, player: "Alice", netCash: 0)
            assertBalance(result, player: "Bob", netCash: 0)
            assertBalance(result, player: "Charlie", netCash: 0)
            assertNoPlayerTransfers(result)
        }

        @Test("Only deposits no withdrawals")
        func onlyDeposits() {
            // Given: Только депозиты в банк, никаких выдач
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 180)  // +80
                .addPlayer("Bob", buyIn: 100, cashOut: 20)     // -80
                .withBank()
                .addBankDeposit(player: "Bob", amount: 80)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Все выплаты через банк
            assertBankTransferCount(result, count: 1)
            assertBankTransfer(result, to: "Alice", amount: 80)
            assertNoPlayerTransfers(result)
        }

        @Test("Only withdrawals no deposits - overdraft scenario")
        func onlyWithdrawals() {
            // Given: Только выдачи, без депозитов (технически невозможно в реальности, но проверим)
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 180)  // +80
                .addPlayer("Bob", buyIn: 100, cashOut: 20)     // -80
                .withBank()
                .addBankWithdrawal(player: "Alice", amount: 30)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: Alice получила 30₽, осталось 50₽ прямым переводом
            assertBankTransferCount(result, count: 0)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 50)
        }

        @Test("Zero net contributions - deposits and withdrawals cancel out")
        func zeroNetContributions() {
            // Given: Bob внёс 50₽ и получил обратно 50₽
            let session = SessionBuilder()
                .withChipRatio(1)
                .addPlayer("Alice", buyIn: 100, cashOut: 150)
                .addPlayer("Bob", buyIn: 100, cashOut: 50)
                .withBank()
                .addBankDeposit(player: "Bob", amount: 50)
                .addBankWithdrawal(player: "Bob", amount: 50)
                .build()

            // When: Рассчитываем settlement
            let result = service.calculateWithBank(for: session)

            // Then: netContribution = 0, как будто банка не было
            assertBalance(result, player: "Alice", netCash: 50)
            assertBalance(result, player: "Bob", netCash: -50)
            assertNoBankTransfers(result)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 50)
        }

        @Test("Large numbers - stress test with big chip amounts")
        func largeNumbers() {
            // Given: Большие суммы
            let session = SessionBuilder()
                .withChipRatio(100)  // 100 фишек = 1₽
                .addPlayer("Alice", buyIn: 1_000_000, cashOut: 1_500_000)  // +500k фишек = +5000₽
                .addPlayer("Bob", buyIn: 1_000_000, cashOut: 500_000)      // -500k фишек = -5000₽
                .build()

            // When: Рассчитываем settlement
            let result = service.calculate(for: session)

            // Then: Правильная конвертация
            assertBalance(result, player: "Alice", netCash: 5000)
            assertBalance(result, player: "Bob", netCash: -5000)
            assertPlayerTransfer(result, from: "Bob", to: "Alice", amount: 5000)
        }

        @Test("Реалистичная сессия на 9 игроков с банком - комплексный сценарий")
        func реалистичнаяСессияНаДевятьИгроков() {
            /*
             ОПИСАНИЕ СЕССИИ:
             ================

             Домашняя игра в покер на 9 человек. Курс: 1 фишка = 1 рубль.

             ИГРОКИ И ИХ РЕЗУЛЬТАТЫ:
             -----------------------
             1. Алексей  - большой победитель, закупился 10000₽, вывел 25000₽ → выигрыш +15000₽
             2. Борис    - средний победитель, закупился 10000₽, вывел 18000₽ → выигрыш +8000₽
             3. Виктор   - небольшой победитель, закупился 10000₽, вывел 13000₽ → выигрыш +3000₽
             4. Григорий - в нуле, закупился 10000₽, вывел 10000₽ → результат 0₽
             5. Дмитрий  - небольшой проигрыш, закупился 10000₽, вывел 8000₽ → проигрыш -2000₽
             6. Евгений  - средний проигрыш, закупился 10000₽, вывел 5000₽ → проигрыш -5000₽
             7. Жанна    - средний проигрыш, закупился 10000₽, вывел 6000₽ → проигрыш -4000₽
             8. Зинаида  - большой проигрыш, закупился 10000₽, вывел 2000₽ → проигрыш -8000₽
             9. Игорь    - большой проигрыш, закупился 10000₽, вывел 3000₽ → проигрыш -7000₽

             Проверка баланса: выигрыши = 15000 + 8000 + 3000 = 26000₽
                             проигрыши = 2000 + 5000 + 4000 + 8000 + 7000 = 26000₽ ✅

             ОПЕРАЦИИ С БАНКОМ:
             ------------------
             1. Дмитрий внёс в банк 1500₽ (из долга 2000₽, осталось 500₽)
             2. Евгений внёс в банк 5000₽ (полностью покрыл долг 5000₽)
             3. Жанна внесла в банк 2000₽ (из долга 4000₽, осталось 2000₽)
             4. Зинаида внесла в банк 3000₽ (из долга 8000₽, осталось 5000₽)
             5. Алексей получил из банка 5000₽ (частичная выплата его выигрыша)
             6. Борис получил из банка 2000₽ (частичная выплата его выигрыша)

             Баланс банка:
             - Внесено: 1500 + 5000 + 2000 + 3000 = 11500₽
             - Выдано: 5000 + 2000 = 7000₽
             - Остаток в банке: 4500₽

             ОЖИДАЕМЫЙ РАСЧЁТ:
             -----------------

             Net contributions (внесено - выдано):
             - Дмитрий: 1500 - 0 = +1500₽
             - Евгений: 5000 - 0 = +5000₽
             - Жанна: 2000 - 0 = +2000₽
             - Зинаида: 3000 - 0 = +3000₽
             - Алексей: 0 - 5000 = -5000₽
             - Борис: 0 - 2000 = -2000₽

             Скорректированные балансы после учёта банка:

             Winners (кредиторы):
             - Алексей: 15000 + (-5000) = 10000₽ нужно получить
             - Борис: 8000 + (-2000) = 6000₽ нужно получить
             - Виктор: 3000 + 0 = 3000₽ нужно получить

             Losers (должники):
             - Дмитрий: 2000 - 1500 = 500₽ нужно отдать
             - Евгений: 5000 - 5000 = 0₽ (долг полностью покрыт через банк)
             - Жанна: 4000 - 2000 = 2000₽ нужно отдать
             - Зинаида: 8000 - 3000 = 5000₽ нужно отдать
             - Игорь: 7000 - 0 = 7000₽ нужно отдать

             Активные депозиты для распределения через банк:
             - Дмитрий: 1500₽
             - Евгений: 5000₽
             - Жанна: 2000₽
             - Зинаида: 3000₽
             Итого: 11500₽

             Жадный алгоритм распределения депозитов (сначала самому большому winner):
             1. Алексей (нужно 10000₽) ← Евгений (5000₽) → остаток Алексей 5000₽
             2. Алексей (нужно 5000₽) ← Зинаида (3000₽) → остаток Алексей 2000₽
             3. Алексей (нужно 2000₽) ← Жанна (2000₽) → Алексей удовлетворён, остаток Жанна 0₽
             4. Борис (нужно 6000₽) ← Дмитрий (1500₽) → остаток Борис 4500₽
             5. Борис готов, но депозитов больше нет

             ПЕРЕВОДЫ ИЗ БАНКА:
             - Алексею: 10000₽ (5000 + 3000 + 2000 из депозитов)
             - Борису: 1500₽ (из депозита Дмитрия)

             ПРЯМЫЕ ПЕРЕВОДЫ между игроками:
             После распределения депозитов через банк:
             - Борису нужно ещё: 6000 - 1500 = 4500₽
             - Виктору нужно: 3000₽

             Должники:
             - Дмитрий: 0₽ (покрыл через банк)
             - Евгений: 0₽ (покрыл через банк)
             - Жанна: 0₽ (покрыла через банк)
             - Зинаида: 0₽ (покрыла через банк)
             - Игорь: 7000₽ (ничего не вносил)

             Прямые переводы (жадный алгоритм):
             1. Игорь → Борису: 4500₽
             2. Игорь → Виктору: 2500₽ (остаток от 7000₽)
             3. Дмитрий → Виктору: 500₽ (остаток долга Дмитрия)
             4. Жанна → Виктору: остаток = 3000 - 2500 - 500 = 0₽ (но у Жанны долг был 2000₽)

             ПЕРЕСЧЁТ ПРЯМЫХ ПЕРЕВОДОВ:
             Должники после банка:
             - Дмитрий: 500₽
             - Жанна: 2000₽
             - Зинаида: 5000₽
             - Игорь: 7000₽

             Кредиторы после банка:
             - Борис: 4500₽
             - Виктор: 3000₽

             Жадный алгоритм P2P:
             1. Игорь (7000) → Борису (4500) = 4500₽, остаток Игорь 2500₽
             2. Игорь (2500) → Виктору (3000) = 2500₽, остаток Виктор 500₽
             3. Зинаида (5000) → Виктору (500) = 500₽, остаток Зинаида 4500₽

             НО ОСТАЮТСЯ: Зинаида 4500₽, Жанна 2000₽, Дмитрий 500₽ = 7000₽
             А кредиторов нет! ОШИБКА В РАСЧЁТАХ!

             ПРАВИЛЬНЫЙ РАСЧЁТ:
             ==================
             Проверка: сумма всех депозитов = 11500₽
             Алексей уже получил 5000₽, Борис 2000₽ = 7000₽ выдано
             В банке осталось: 11500 - 7000 = 4500₽

             Этот остаток должен пойти к winners.
             Но Алексей netContribution = -5000 (получил больше)
             Борис netContribution = -2000 (получил больше)

             Правильная логика:
             Активные депозиты (положительные netContribution) идут winners.
             11500₽ депозитов распределяются между Алексей (10000), Борис (6000), Виктор (3000).

             Жадный:
             1. Алексей ← 10000₽ из депозитов (Евгений 5000, Зинаида 3000, Жанна 2000)
             2. Борис ← 1500₽ (Дмитрий)
             3. Остаток Борис нужно 4500₽, Виктор 3000₽ = 7500₽
             4. Нет больше депозитов

             Прямые переводы от оставшихся должников:
             - Дмитрий: долг покрыт
             - Евгений: долг покрыт
             - Жанна: долг покрыт
             - Зинаида: долг покрыт
             - Игорь: 7000₽ долг

             НО 7000 < 7500! Ошибка в условии задачи!

             ИСПРАВЛЕНИЕ: Игорь тоже внёс в банк!
             */

            // Given: Реалистичная домашняя игра на 9 человек
            let session = SessionBuilder()
                .withChipRatio(1)
                // Победители
                .addPlayer("Алексей", buyIn: 10000, cashOut: 25000)  // +15000₽
                .addPlayer("Борис", buyIn: 10000, cashOut: 18000)    // +8000₽
                .addPlayer("Виктор", buyIn: 10000, cashOut: 13000)   // +3000₽
                .addPlayer("Григорий", buyIn: 10000, cashOut: 10000) // 0₽
                // Проигравшие
                .addPlayer("Дмитрий", buyIn: 10000, cashOut: 8000)   // -2000₽
                .addPlayer("Евгений", buyIn: 10000, cashOut: 5000)   // -5000₽
                .addPlayer("Жанна", buyIn: 10000, cashOut: 6000)     // -4000₽
                .addPlayer("Зинаида", buyIn: 10000, cashOut: 2000)   // -8000₽
                .addPlayer("Игорь", buyIn: 10000, cashOut: 3000)     // -7000₽
                // Банк сессии
                .withBank()
                // Депозиты (проигравшие вносят деньги)
                .addBankDeposit(player: "Дмитрий", amount: 1500)
                .addBankDeposit(player: "Евгений", amount: 5000)
                .addBankDeposit(player: "Жанна", amount: 2000)
                .addBankDeposit(player: "Зинаида", amount: 3000)
                .addBankDeposit(player: "Игорь", amount: 7000)  // Игорь внёс весь долг
                // Выдачи (победители получают)
                .addBankWithdrawal(player: "Алексей", amount: 5000)
                .addBankWithdrawal(player: "Борис", amount: 2000)
                .build()

            // When: Рассчитываем settlement с учётом банка
            let result = service.calculateWithBank(for: session)

            // Then: Проверяем балансы всех игроков
            assertBalance(result, player: "Алексей", netCash: 15000)
            assertBalance(result, player: "Борис", netCash: 8000)
            assertBalance(result, player: "Виктор", netCash: 3000)
            assertBalance(result, player: "Григорий", netCash: 0)
            assertBalance(result, player: "Дмитрий", netCash: -2000)
            assertBalance(result, player: "Евгений", netCash: -5000)
            assertBalance(result, player: "Жанна", netCash: -4000)
            assertBalance(result, player: "Зинаида", netCash: -8000)
            assertBalance(result, player: "Игорь", netCash: -7000)

            /*
             РАСЧЁТ ПЕРЕВОДОВ ИЗ БАНКА:

             Net contributions:
             - Дмитрий: 1500
             - Евгений: 5000
             - Жанна: 2000
             - Зинаида: 3000
             - Игорь: 7000
             - Алексей: -5000
             - Борис: -2000

             Скорректированные winners (после вычета уже полученного):
             - Алексей: 15000 + (-5000) = 10000₽
             - Борис: 8000 + (-2000) = 6000₽
             - Виктор: 3000₽

             Скорректированные losers (после вычета внесённого):
             - Дмитрий: 2000 - 1500 = 500₽
             - Евгений: 5000 - 5000 = 0₽
             - Жанна: 4000 - 2000 = 2000₽
             - Зинаида: 8000 - 3000 = 5000₽
             - Игорь: 7000 - 7000 = 0₽

             Активные депозиты: 1500 + 5000 + 2000 + 3000 + 7000 = 18500₽
             Нужно winners: 10000 + 6000 + 3000 = 19000₽

             Жадный алгоритм (депозиты → winners, сортировка по убыванию):
             Депозиты: Игорь(7000), Евгений(5000), Зинаида(3000), Жанна(2000), Дмитрий(1500)
             Winners: Алексей(10000), Борис(6000), Виктор(3000)

             1. Игорь(7000) → Алексей(10000): 7000₽, остаток Алексей 3000
             2. Евгений(5000) → Алексей(3000): 3000₽, остаток Евгений 2000
             3. Евгений(2000) → Борис(6000): 2000₽, остаток Борис 4000
             4. Зинаида(3000) → Борис(4000): 3000₽, остаток Борис 1000
             5. Жанна(2000) → Борис(1000): 1000₽, остаток Жанна 1000
             6. Жанна(1000) → Виктор(3000): 1000₽, остаток Виктор 2000
             7. Дмитрий(1500) → Виктор(2000): 1500₽, остаток Виктор 500

             ПЕРЕВОДЫ ИЗ БАНКА:
             - Алексей: 10000₽
             - Борис: 6000₽
             - Виктор: 2500₽

             Остаток Виктор нужно 500₽
             Но все депозиты закончились!
             Значит нужны прямые переводы.

             Но кто должен?
             После депозитов:
             - Дмитрий: 500 - 1500 = уже переплатил через депозит? НЕТ!

             Adjusted debt после депозитов:
             - Дмитрий: 500₽ (2000 - 1500)
             - Жанна: 2000₽ (4000 - 2000)
             - Зинаида: 5000₽ (8000 - 3000)

             Но они уже внесли в банк, и банк уже передал winners!
             Их долг = 500 + 2000 + 5000 = 7500₽
             Виктору нужно: 500₽

             Прямые переводы:
             - Дмитрий → Виктору: 500₽
             */

            // Проверяем переводы из банка (3 перевода)
            assertBankTransferCount(result, count: 3)
            assertBankTransfer(result, to: "Алексей", amount: 10000)
            assertBankTransfer(result, to: "Борис", amount: 6000)
            assertBankTransfer(result, to: "Виктор", amount: 2500)

            // Проверяем прямые переводы (только 1 перевод)
            assertPlayerTransferCount(result, count: 1)
            assertPlayerTransfer(result, from: "Дмитрий", to: "Виктор", amount: 500)
        }
    }
}
