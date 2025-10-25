//
//  MainView.swift
//  Home Poker
//
//  Created by Odds on 23.10.2025.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            Tab("Сессии", systemImage: "list.star") {
                SessionListView()
            }
            Tab("Таймер", systemImage: "timer") {
                TimerView()
            }
        }
    }
}

#Preview {
    MainView()
}
