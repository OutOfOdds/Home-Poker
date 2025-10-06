//
//  Player.swift
//  Home Poker
//
//  Created by Odds on 02.10.2025.
//

import Foundation
import SwiftData

@Model
class Player {
    // Данные игрока
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var isActive: Bool = true
    var buyIn: Int
    var cashOut: Int = 0
    var getsRakeback: Bool = false
    var rakeback: Int = 0
    
    init(name: String, isActive: Bool = true, buyIn: Int) {
        self.name = name
        self.isActive = isActive
        self.buyIn = buyIn
    }
    
    var profit: Int { cashOut - buyIn }
    var balance: Int { isActive ? buyIn - cashOut : 0 }
    var profitAfterRakeback: Int { profit - rakeback }
}
