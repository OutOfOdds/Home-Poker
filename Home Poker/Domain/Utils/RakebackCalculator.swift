//
//  RakebackCalculator.swift
//  Home Poker
//
//  Utility for rakeback distribution calculations
//  Used by UI layer for local computations before saving
//

import Foundation

struct RakebackCalculator {

    // MARK: - Distribution Methods

    /// Distributes amount equally among selected players
    /// Returns array of amounts with remainder distributed to first players
    static func distributeEqually(totalAmount: Int, playerCount: Int) -> [Int] {
        guard playerCount > 0 else { return [] }

        let amountPerPlayer = totalAmount / playerCount
        let remainder = totalAmount % playerCount

        var amounts: [Int] = []
        for index in 0..<playerCount {
            let amount = amountPerPlayer + (index < remainder ? 1 : 0)
            amounts.append(amount)
        }

        return amounts
    }

    /// Distributes amount by percentages
    /// Returns array of amounts based on percentage distribution
    static func distributeByPercentage(totalAmount: Int, percentages: [Int]) -> [Int] {
        var amounts: [Int] = []
        var distributed = 0

        for (index, percentage) in percentages.enumerated() {
            let amount: Int

            // Last player gets remainder to ensure exact total
            if index == percentages.count - 1 {
                amount = totalAmount - distributed
            } else {
                amount = Int((Double(totalAmount) * Double(percentage) / 100.0).rounded())
                distributed += amount
            }

            amounts.append(amount)
        }

        return amounts
    }

    /// Calculates percentage for equal distribution
    static func equalPercentage(playerCount: Int) -> [Int] {
        guard playerCount > 0 else { return [] }

        let percentagePerPlayer = 100 / playerCount
        let remainder = 100 % playerCount

        var percentages: [Int] = []
        for index in 0..<playerCount {
            let percentage = percentagePerPlayer + (index < remainder ? 1 : 0)
            percentages.append(percentage)
        }

        return percentages
    }

}

// MARK: - Distribution Mode

enum DistributionMode {
    case equal
    case percentage
    case manual
}
