//
//  TimerViewModel.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import Foundation
import SwiftUI
import Observation

@Observable
final class TimerViewModel {

    // MARK: - Services

    private let generator = BlindStructureGenerator()
    private let timerService: SessionTimerServiceProtocol

    // MARK: - State

    var items: [LevelItem] = []
    var isConfigured: Bool = false
    var tournamentConfig: BlindConfig
    var showConfigForm: Bool = true

    // MARK: - Computed Properties

    var currentState: TimerState? {
        timerService.currentState
    }

    // MARK: - Initialization

    init(timerService: SessionTimerServiceProtocol = SessionTimerService()) {
        self.timerService = timerService
        // Инициализируем конфиг значениями по умолчанию
        self.tournamentConfig = BlindConfig(
            players: 10,
            hours: 4.0,
            roundMinutes: 12,
            smallestDenomination: 25,
            startingChips: 10000,
            startingSmallBlind: 25,
            rebuysExpected: 2,
            rebuyChips: 10000,
            addOnsExpected: 3,
            addOnChips: 10000,
            useAntes: true
        )
    }

    // MARK: - Public Methods

    /// Запускает турнир с текущей конфигурацией
    func startTournament() {
        // Генерируем структуру на основе конфига
        let levels = generator.generateLevels(config: tournamentConfig)
        items = levels.map { .blinds($0) }
        isConfigured = !items.isEmpty

        // Скрываем форму конфигурации
        showConfigForm = false

        // Запускаем таймер
        startTimer()
    }

    /// Сбрасывает турнир и возвращает к форме настройки
    func resetToConfig() {
        stopTimer()
        items = []
        isConfigured = false
        showConfigForm = true
    }

    /// Запускает таймер
    func startTimer() {
        guard !items.isEmpty else { return }
        withAnimation {
            timerService.start(items: items, startedAt: Date())
        }
    }

    /// Переключает паузу/возобновление
    func togglePause() {
        guard let state = currentState else { return }

        withAnimation {
            if state.isPaused {
                timerService.resume()
            } else {
                timerService.pause()
            }
        }
    }

    /// Останавливает таймер полностью
    func stopTimer() {
        timerService.stop()
    }

    /// Переход к следующему уровню
    func skipToNext() {
        withAnimation {
            timerService.skipToNext()
        }
    }

    /// Возврат к предыдущему уровню
    func skipToPrevious() {
        withAnimation {
            timerService.skipToPrevious()
        }
    }

    /// Переход к конкретному уровню
    func jumpToLevel(at index: Int) {
        withAnimation {
            timerService.jumpToLevel(at: index)
        }
    }

    // MARK: - Level Editing

    /// Обновляет уровень (только ручное редактирование, без автоматических пересчётов)
    func updateLevel(at index: Int, smallBlind: Int, bigBlind: Int, ante: Int) {
        guard items.indices.contains(index) else { return }
        guard case .blinds(let level) = items[index] else { return }

        // Создаём обновлённый уровень
        let updatedLevel = BlindLevel(
            index: level.index,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            ante: ante,
            minutes: level.minutes
        )
        items[index] = .blinds(updatedLevel)
    }

    // MARK: - Formatting

    /// Форматирует TimeInterval в строку вида "12:45" или "1:05:30"
    func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Форматирует блайнды для отображения
    func formatBlinds(for item: LevelItem) -> String {
        switch item {
        case .blinds(let level):
            if level.ante > 0 {
                return "\(level.smallBlind)/\(level.bigBlind) (\(level.ante))"
            } else {
                return "\(level.smallBlind)/\(level.bigBlind)"
            }
        case .break(let breakInfo):
            return breakInfo.title
        }
    }

    /// Возвращает название уровня
    func levelTitle(for item: LevelItem) -> String {
        switch item {
        case .blinds(let level):
            return "Уровень \(level.index)"
        case .break(let breakInfo):
            return breakInfo.title
        }
    }

    /// Возвращает длительность уровня в минутах
    func levelDuration(for item: LevelItem) -> Int {
        switch item {
        case .blinds(let level):
            return level.minutes
        case .break(let breakInfo):
            return breakInfo.minutes
        }
    }

    // MARK: - Computed Properties

    var isRunning: Bool {
        currentState?.isRunning ?? false
    }

    var isPaused: Bool {
        currentState?.isPaused ?? false
    }

    var canStart: Bool {
        isConfigured && !isRunning
    }

    var canPause: Bool {
        isRunning && !isPaused
    }

    var canResume: Bool {
        isRunning && isPaused
    }
}
