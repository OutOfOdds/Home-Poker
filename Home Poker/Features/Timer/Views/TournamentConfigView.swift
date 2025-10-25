//
//  TournamentConfigView.swift
//  Home Poker
//
//  Created by Claude on 25.10.2025.
//

import SwiftUI

struct TournamentConfigView: View {
    @Binding var config: BlindConfig
    let onStart: () -> Void

    var body: some View {
        Form {
            Section("Основные параметры") {
                Stepper("Игроков: \(config.players)", value: $config.players, in: 2...50)

                HStack {
                    Text("Длительность (часы)")
                    Spacer()
                    TextField("Часы", value: $config.hours, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                Stepper("Раунд (мин): \(config.roundMinutes)", value: $config.roundMinutes, in: 5...60, step: 5)
            }

            Section("Фишки") {
                HStack {
                    Text("Стартовый стек")
                    Spacer()
                    TextField("Стек", value: $config.startingChips, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                HStack {
                    Text("Мин. номинал")
                    Spacer()
                    TextField("Номинал", value: $config.smallestDenomination, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                HStack {
                    Text("Стартовый SB")
                    Spacer()
                    TextField("SB", value: $config.startingSmallBlind, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section("Ребаи и аддоны") {
                Stepper("Ребаев ожидается: \(config.rebuysExpected)", value: $config.rebuysExpected, in: 0...20)

                HStack {
                    Text("Фишек за ребай")
                    Spacer()
                    TextField("Фишки", value: $config.rebuyChips, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                Stepper("Аддонов ожидается: \(config.addOnsExpected)", value: $config.addOnsExpected, in: 0...20)

                HStack {
                    Text("Фишек за аддон")
                    Spacer()
                    TextField("Фишки", value: $config.addOnChips, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section("Дополнительно") {
                Toggle("Использовать анте", isOn: $config.useAntes)

                Stepper("Запасных уровней: \(config.extraLevels)", value: $config.extraLevels, in: 0...10)
            }

            Section {
                Button(action: onStart) {
                    HStack {
                        Spacer()
                        Label("Начать турнир", systemImage: "play.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Настройка турнира")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TournamentConfigView(
            config: .constant(BlindConfig(
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
            )),
            onStart: { print("Start!") }
        )
    }
}
