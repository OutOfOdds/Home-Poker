//
//  Home_PokerApp.swift
//  Home Poker
//
//  Created by Odds on 02.10.2025.
//

import SwiftUI
import SwiftData


@main
struct Home_PokerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Player.self,Session.self, Expense.self])
    }
}
