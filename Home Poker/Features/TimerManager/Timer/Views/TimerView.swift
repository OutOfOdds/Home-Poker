//
//  TimerView.swift
//  Home Poker
//
//  Created by Odds on 26.10.2025.
//

import SwiftUI

struct TimerView: View {
    var body: some View {
        TimerLevelCard()
            .listRowSeparator(.hidden)

        Section {
            NextLevelPreview()
        }
        Section {
            TimerControlsPanel()
        }
    }
}

#Preview("Ожидание запуска") {
    TimerView()
        .environment(PreviewData.timerViewModel(.notStarted))
}

#Preview("Таймер запущен") {
    TimerView()
        .environment(PreviewData.timerViewModel(.running(level: 1)))
}
