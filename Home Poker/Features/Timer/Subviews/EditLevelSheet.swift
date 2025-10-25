//
//  EditLevelSheet.swift
//  Home Poker
//
//  Created by Odds on 24.10.2025.
//

import SwiftUI

struct EditLevelSheet: View {
    let levelIndex: Int
    let currentLevel: BlindLevel
    let viewModel: TimerViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var smallBlind: String
    @State private var bigBlind: String
    @State private var ante: String

    init(levelIndex: Int, currentLevel: BlindLevel, viewModel: TimerViewModel) {
        self.levelIndex = levelIndex
        self.currentLevel = currentLevel
        self.viewModel = viewModel

        _smallBlind = State(initialValue: String(currentLevel.smallBlind))
        _bigBlind = State(initialValue: String(currentLevel.bigBlind))
        _ante = State(initialValue: String(currentLevel.ante))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Small Blind")
                        Spacer()
                        TextField("SB", text: $smallBlind)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", text: $bigBlind)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $ante)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Уровень \(currentLevel.index)")
                } footer: {
                    Text("После сохранения все последующие уровни будут пересчитаны автоматически.")
                }
            }
            .navigationTitle("Редактировать уровень")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let sb = Int(smallBlind), sb > 0,
              let bb = Int(bigBlind), bb > 0,
              let _ = Int(ante) else {
            return false
        }
        return sb <= bb
    }

    private func saveChanges() {
        guard let sb = Int(smallBlind),
              let bb = Int(bigBlind),
              let ante = Int(ante) else {
            return
        }

        viewModel.updateLevel(at: levelIndex, smallBlind: sb, bigBlind: bb, ante: ante)
        dismiss()
    }
}
