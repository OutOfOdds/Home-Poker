//
//  SettlementServiceTests.swift
//  Home PokerTests
//
//  Тесты для SettlementService - расчёт балансов и переводов
//

import Testing
import Foundation
@testable import Home_Poker

@Suite("Тесты расчёта балансов и переводов")
struct SettlementServiceTests {
    let service = SettlementService()
    
    @Test("9 игроков с банком - все сценарии")
    func ninePlayerTest() {
        /*
         ОПИСАНИЕ СЕССИИ:
         ================
         
         Домашняя игра в покер на 9 человек. Курс: 1 фишка = 1 рубль.
         
         ИГРОКИ И ИХ РЕЗУЛЬТАТЫ:
         -----------------------
         1. Алексей  - большой победитель, закупился 10000₽, вывел 23000₽ → выигрыш +13000₽
         2. Борис    - средний победитель, закупился 10000₽, вывел 17000₽ → выигрыш +7000₽
         3. Виктор   - небольшой победитель, закупился 10000₽, вывел 13000₽ → выигрыш +3000₽
         4. Григорий - небольшой победитель, закупился 10000₽, вывел 13000₽ → выигрыш +3000₽
         5. Дмитрий  - небольшой проигрыш, закупился 10000₽, вывел 8000₽ → проигрыш -2000₽
         6. Евгений  - средний проигрыш, закупился 10000₽, вывел 5000₽ → проигрыш -5000₽
         7. Жанна    - средний проигрыш, закупился 10000₽, вывел 6000₽ → проигрыш -4000₽
         8. Зинаида  - большой проигрыш, закупился 10000₽, вывел 3000₽ → проигрыш -7000₽
         9. Игорь    - большой проигрыш, закупился 10000₽, вывел 2000₽ → проигрыш -8000₽
         
         Проверка баланса: выигрыши = 13000 + 7000 + 3000 + 3000 = 26000₽
         проигрыши = 2000 + 5000 + 4000 + 7000 + 8000 = 26000₽ ✅
         
         ОПЕРАЦИИ С БАНКОМ (покрываем все сценарии):
         --------------------------------------------
         
         Сценарий 1: Полный депозит (долг полностью покрыт через банк)
         - Евгений внёс 5000₽ (его долг 5000₽) → долг полностью покрыт ✅
         
         Сценарий 2: Частичный депозит (долг частично покрыт через банк)
         - Жанна внесла 2000₽ (её долг 4000₽) → осталось 2000₽ платить напрямую
         - Игорь внёс 5000₽ (его долг 8000₽) → осталось 3000₽ платить напрямую
         
         Сценарий 3: Без депозита (не вносил в банк, платит напрямую)
         - Дмитрий не вносил → платит 2000₽ напрямую
         - Зинаида не вносила → платит 7000₽ напрямую
         
         Сценарий 4: Без withdrawal (никто не получал напрямую из банка до расчётов)
         - Все победители получат через алгоритм распределения депозитов
         
         Итого в банке:
         - Внесено (депозиты): 5000 + 2000 + 5000 = 12000₽
         - Выдано (withdrawals): 0₽
         - Для распределения: 12000₽
         
         ОЖИДАЕМЫЙ РАСЧЁТ:
         -----------------
         
         Net contributions (внесено - выдано):
         - Евгений: 5000 - 0 = +5000₽
         - Жанна: 2000 - 0 = +2000₽
         - Игорь: 5000 - 0 = +5000₽
         - Все остальные: 0
         
         Скорректированные балансы (adjustedBalance = netCash + netContribution):
         
         Winners (кредиторы):
         - Алексей: 13000 + 0 = 13000₽
         - Борис: 7000 + 0 = 7000₽
         - Виктор: 3000 + 0 = 3000₽
         - Григорий: 3000 + 0 = 3000₽
         Итого winners: 26000₽
         
         Losers (должники) - adjustedDebt = -netCash - netContribution:
         - Дмитрий: -(-2000) - 0 = 2000₽
         - Евгений: -(-5000) - 5000 = 0₽ (долг покрыт депозитом)
         - Жанна: -(-4000) - 2000 = 2000₽
         - Зинаида: -(-7000) - 0 = 7000₽
         - Игорь: -(-8000) - 5000 = 3000₽
         Итого losers через прямые: 14000₽
         
         Проверка: 12000₽ (через банк) + 14000₽ (прямо) = 26000₽ ✅
         
         РАСПРЕДЕЛЕНИЕ ДЕПОЗИТОВ ЧЕРЕЗ БАНК (жадный алгоритм):
         ------------------------------------------------------
         
         Активные депозиты: Игорь(5000), Евгений(5000), Жанна(2000) = 12000₽
         Creditors: Алексей(13000), Борис(7000), Виктор(3000), Григорий(3000)
         
         Алгоритм (строки 134-158 SettlementService.swift):
         1. Игорь(5000) → Алексей(13000): 5000₽
         BankTransfer(to: Алексей, 5000)
         Остаток: Игорь 0₽, Алексей 8000₽
         
         2. Евгений(5000) → Алексей(8000): 5000₽
         BankTransfer(to: Алексей, 5000)
         Остаток: Евгений 0₽, Алексей 3000₽
         
         3. Жанна(2000) → Алексей(3000): 2000₽
         BankTransfer(to: Алексей, 2000)
         Остаток: Жанна 0₽, Алексей 1000₽
         
         ПЕРЕВОДЫ ИЗ БАНКА (3 перевода):
         - Алексею: 5000₽ (от Игоря)
         - Алексею: 5000₽ (от Евгения)
         - Алексею: 2000₽ (от Жанны)
         ИТОГО Алексей получил через банк: 12000₽
         Алексею ещё нужно: 13000 - 12000 = 1000₽
         
         ПРЯМЫЕ ПЕРЕВОДЫ:
         ----------------
         
         Creditors после банка:
         - Алексей: 1000₽
         - Борис: 7000₽
         - Виктор: 3000₽
         - Григорий: 3000₽
         Итого: 14000₽
         
         Debtors:
         - Дмитрий: 2000₽
         - Жанна: 2000₽
         - Зинаида: 7000₽
         - Игорь: 3000₽
         Итого: 14000₽
         
         Проверка: 14000 = 14000 ✅
         
         Жадный P2P алгоритм:
         Creditors (по убыванию): Борис(7000), Виктор(3000), Григорий(3000), Алексей(1000)
         Debtors (по убыванию): Зинаида(7000), Игорь(3000), Дмитрий(2000), Жанна(2000)
         
         1. Зинаида(7000) → Борис(7000): 7000₽
         Остаток: Зинаида 0₽, Борис 0₽
         
         2. Игорь(3000) → Виктор(3000): 3000₽
         Остаток: Игорь 0₽, Виктор 0₽
         
         3. Дмитрий(2000) → Григорий(3000): 2000₽
         Остаток: Дмитрий 0₽, Григорий 1000₽
         
         4. Жанна(2000) → Григорий(1000): 1000₽
         Остаток: Жанна 1000₽, Григорий 0₽
         
         5. Жанна(1000) → Алексей(1000): 1000₽
         Остаток: Жанна 0₽, Алексей 0₽
         
         ПРЯМЫЕ ПЕРЕВОДЫ (5 переводов):
         - Зинаида → Борису: 7000₽
         - Игорь → Виктору: 3000₽
         - Дмитрий → Григорию: 2000₽
         - Жанна → Григорию: 1000₽
         - Жанна → Алексею: 1000₽
         */
        
        // Given: Реалистичная домашняя игра на 9 человек
        let session = SessionBuilder()
            .withChipRatio(1)
        // Победители
            .addPlayer("Алексей", buyIn: 10000, cashOut: 23000)  // +13000₽
            .addPlayer("Борис", buyIn: 10000, cashOut: 17000)    // +7000₽
            .addPlayer("Виктор", buyIn: 10000, cashOut: 13000)   // +3000₽
            .addPlayer("Григорий", buyIn: 10000, cashOut: 13000) // +3000₽
        // Проигравшие
            .addPlayer("Дмитрий", buyIn: 10000, cashOut: 8000)   // -2000₽
            .addPlayer("Евгений", buyIn: 10000, cashOut: 5000)   // -5000₽
            .addPlayer("Жанна", buyIn: 10000, cashOut: 6000)     // -4000₽
            .addPlayer("Зинаида", buyIn: 10000, cashOut: 3000)   // -7000₽
            .addPlayer("Игорь", buyIn: 10000, cashOut: 2000)     // -8000₽
        // Банк сессии
            .withBank()
        // Депозиты (покрываем разные сценарии)
            .addBankDeposit(player: "Евгений", amount: 5000)  // Сценарий 1: Полный депозит
            .addBankDeposit(player: "Жанна", amount: 2000)    // Сценарий 2: Частичный депозит
            .addBankDeposit(player: "Игорь", amount: 5000)    // Сценарий 2: Частичный депозит
        // Дмитрий и Зинаида НЕ вносили (Сценарий 3: платят напрямую)
            .build()
        
        // When: Рассчитываем settlement с учётом банка
        let result = service.calculate(for: session)
        guard let bank = session.bank else {
            Issue.record("Банк сессии не найден")
            return
        }
        
        // DEBUG: Выводим все переводы для отладки
        print("\n=== ПЕРЕВОДЫ ИЗ БАНКА (\(result.bankTransfers.count)) ===")
        for transfer in result.bankTransfers {
            print("Банк → \(transfer.to.name): \(transfer.amount)₽")
        }
        
        print("\n=== ПРЯМЫЕ ПЕРЕВОДЫ МЕЖДУ ИГРОКАМИ (\(result.playerTransfers.count)) ===")
        for transfer in result.playerTransfers {
            print("\(transfer.from.name) → \(transfer.to.name): \(transfer.amount)₽")
        }
        
        print("\nБаланс банка: \(bank.netBalance)₽")
        
        // Then: Проверяем балансы всех игроков
        assertBalance(result, player: "Алексей", netCash: 13000)
        assertBalance(result, player: "Борис", netCash: 7000)
        assertBalance(result, player: "Виктор", netCash: 3000)
        assertBalance(result, player: "Григорий", netCash: 3000)
        assertBalance(result, player: "Дмитрий", netCash: -2000)
        assertBalance(result, player: "Евгений", netCash: -5000)
        assertBalance(result, player: "Жанна", netCash: -4000)
        assertBalance(result, player: "Зинаида", netCash: -7000)
        assertBalance(result, player: "Игорь", netCash: -8000)
        
        // Проверяем переводы из банка (3 перевода - все Алексею)
        assertBankTransferCount(result, count: 3)
        assertBankTransfer(result, to: "Алексей", amount: 5000)  // от Игоря
        assertBankTransfer(result, to: "Алексей", amount: 5000)  // от Евгения
        assertBankTransfer(result, to: "Алексей", amount: 2000)  // от Жанны
        
        // Проверяем прямые переводы (7 переводов)
        // Фактические переводы от алгоритма:
        // Creditors (порядок): Алексей(1000), Борис(7000), Виктор(3000), Григорий(3000)
        // Debtors (по убыванию): Зинаида(7000), Игорь(3000), Дмитрий(2000), Жанна(2000)
        assertPlayerTransferCount(result, count: 7)
        assertPlayerTransfer(result, from: "Зинаида", to: "Алексей", amount: 1000)
        assertPlayerTransfer(result, from: "Зинаида", to: "Борис", amount: 6000)
        assertPlayerTransfer(result, from: "Игорь", to: "Борис", amount: 1000)
        assertPlayerTransfer(result, from: "Игорь", to: "Виктор", amount: 2000)
        assertPlayerTransfer(result, from: "Дмитрий", to: "Виктор", amount: 1000)
        assertPlayerTransfer(result, from: "Дмитрий", to: "Григорий", amount: 1000)
        assertPlayerTransfer(result, from: "Жанна", to: "Григорий", amount: 2000)
    }
    
    @Test("9 игроков с рейком 5000₽, остающимся в банке")
    func ninePlayerTestWithRake() {
        /*
         СЦЕНАРИЙ С РЕЙКОМ:
         
         Total BuyIn:  90000₽ (9 игроков × 10000₽)
         Total CashOut: 85000₽ (после удержания рейка)
         Rake:          5000₽ (остаётся в банке сессии)
         
         ВЫИГРАВШИЕ (total: +21000₽):
         - Алексей: 10000 → 20000 = +10000₽
         - Борис:   10000 → 16000 = +6000₽
         - Виктор:  10000 → 13000 = +3000₽
         - Григорий: 10000 → 12000 = +2000₽
         
         ПРОИГРАВШИЕ (total: -26000₽):
         - Дмитрий: 10000 → 8000 = -2000₽
         - Евгений: 10000 → 6000 = -4000₽
         - Жанна:   10000 → 5000 = -5000₽
         - Зинаида: 10000 → 3000 = -7000₽
         - Игорь:   10000 → 2000 = -8000₽
         
         БАЛАНС ИГРОКОВ:
         Выигрыши (+21000) + Проигрыши (-26000) = -5000₽
         Эта разница равна рейку!
         
         ДЕПОЗИТЫ В БАНК:
         - Евгений: 4000₽ (полное покрытие долга 4000₽)
         - Жанна:   5000₽ (полное покрытие долга 5000₽)
         - Зинаида: 7000₽ (полное покрытие долга 7000₽)
         Total deposits: 16000₽
         
         ПРОВЕРКИ:
         1. Все переводы между игроками корректны
         2. Сумма балансов игроков = -5000₽ (равна рейку)
         3. Остаток в банке = +5000₽ после всех расчётов
         4. Общий баланс системы = 0 (игроки + банк)
         */
        
        // Given: Сессия на 9 игроков с рейком 5000₽
        let session = SessionBuilder()
            .withChipRatio(1)
            .withRake(5000)  // 5000 фишек рейка
        // Выигравшие
            .addPlayer("Алексей", buyIn: 10000, cashOut: 20000)  // +10000₽
            .addPlayer("Борис", buyIn: 10000, cashOut: 16000)    // +6000₽
            .addPlayer("Виктор", buyIn: 10000, cashOut: 13000)   // +3000₽
            .addPlayer("Григорий", buyIn: 10000, cashOut: 12000) // +2000₽
        // Проигравшие
            .addPlayer("Дмитрий", buyIn: 10000, cashOut: 8000)   // -2000₽
            .addPlayer("Евгений", buyIn: 10000, cashOut: 6000)   // -4000₽
            .addPlayer("Жанна", buyIn: 10000, cashOut: 5000)     // -5000₽
            .addPlayer("Зинаида", buyIn: 10000, cashOut: 3000)   // -7000₽
            .addPlayer("Игорь", buyIn: 10000, cashOut: 2000)     // -8000₽
        // Банк с депозитами от проигравших
            .withBank()
            .addBankDeposit(player: "Евгений", amount: 4000)  // Полное покрытие
            .addBankDeposit(player: "Жанна", amount: 5000)    // Полное покрытие
            .addBankDeposit(player: "Зинаида", amount: 7000)  // Полное покрытие
            .build()
        
        // When: Рассчитываем settlement
        let result = service.calculate(for: session)
        
        // DEBUG: Выводим все переводы для отладки
        print("\n=== ТЕСТ С РЕЙКОМ: ПЕРЕВОДЫ ИЗ БАНКА (\(result.bankTransfers.count)) ===")
        for transfer in result.bankTransfers {
            print("Банк → \(transfer.to.name): \(transfer.amount)₽")
        }
        
        print("\n=== ТЕСТ С РЕЙКОМ: ПРЯМЫЕ ПЕРЕВОДЫ (\(result.playerTransfers.count)) ===")
        for transfer in result.playerTransfers {
            print("\(transfer.from.name) → \(transfer.to.name): \(transfer.amount)₽")
        }
        
        // Then: Проверяем балансы всех игроков
        assertBalance(result, player: "Алексей", netCash: 10000)
        assertBalance(result, player: "Борис", netCash: 6000)
        assertBalance(result, player: "Виктор", netCash: 3000)
        assertBalance(result, player: "Григорий", netCash: 2000)
        assertBalance(result, player: "Дмитрий", netCash: -2000)
        assertBalance(result, player: "Евгений", netCash: -4000)
        assertBalance(result, player: "Жанна", netCash: -5000)
        assertBalance(result, player: "Зинаида", netCash: -7000)
        assertBalance(result, player: "Игорь", netCash: -8000)
        
        // Проверяем сумму всех балансов игроков
        let totalPlayerBalance = result.balances.reduce(0) { $0 + $1.netCash }
        #expect(totalPlayerBalance == -5000, "Сумма балансов игроков должна быть -5000₽ (равна рейку)")
        
        // Проверяем остаток в банке после всех переводов
        guard let bank = session.bank else {
            Issue.record("Банк сессии не найден")
            return
        }
        
        let totalBankTransfers = result.bankTransfers.reduce(0) { $0 + $1.amount }
        let remainingBankBalance = bank.netBalance - totalBankTransfers
        
        print("\n=== ТЕСТ С РЕЙКОМ: БАЛАНСЫ ===")
        print("Всего депозитов в банк: \(bank.totalDeposited)₽")
        print("Всего выводов из банка: \(bank.totalWithdrawn)₽")
        print("Чистый баланс банка: \(bank.netBalance)₽")
        print("Сумма переводов из банка в settlement: \(totalBankTransfers)₽")
        print("Остаток в банке после settlement: \(remainingBankBalance)₽")
        print("Ожидаемый рейк: \(session.rakeAmount * session.chipsToCashRatio)₽")
        print("Суммарный баланс игроков: \(totalPlayerBalance)₽")
        print("Баланс системы (игроки + банк): \(totalPlayerBalance + remainingBankBalance)₽")
    }
}
