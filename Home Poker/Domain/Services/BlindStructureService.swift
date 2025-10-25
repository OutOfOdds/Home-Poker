//
//  BlindStructureService.swift
//  Home Poker
//
//  Created by ChatGPT on 2025-10-25
//

import Foundation

public struct BlindLevel: Hashable, Codable {
    public let index: Int
    public let smallBlind: Int
    public let bigBlind: Int
    public let ante: Int
    public let minutes: Int

    public init(index: Int, smallBlind: Int, bigBlind: Int, ante: Int, minutes: Int) {
        self.index = index
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.ante = ante
        self.minutes = minutes
    }
}

public enum LevelItem: Hashable {
    case blinds(BlindLevel)
    case `break`(BreakInfo)
}

public struct BreakInfo: Hashable, Codable {
    public var title: String = "Break"
    public var minutes: Int

    public init(title: String = "Break", minutes: Int) {
        self.title = title
        self.minutes = minutes
    }
}

public struct BlindConfig: Hashable, Codable {
    public var players: Int
    public var hours: Double
    public var roundMinutes: Int
    public var smallestDenomination: Int
    public var startingChips: Int
    public var startingSmallBlind: Int

    public var rebuysExpected: Int
    public var rebuyChips: Int
    public var addOnsExpected: Int
    public var addOnChips: Int

    public var useAntes: Bool = true
    public var targetBBShareOfBank: Double = 0.06   // 6% от всех фишек
    public var extraLevels: Int = 0                 // запасные уровни
}

// MARK: - Protocol

public protocol BlindStructureGeneratorProtocol {
    func generateLevels(config: BlindConfig) -> [BlindLevel]
}

// MARK: - Implementation

public final class BlindStructureGenerator: BlindStructureGeneratorProtocol {

    public init() {}

    public func generateLevels(config c: BlindConfig) -> [BlindLevel] {
        // 1. общее количество фишек в игре
        let totalBank = c.players * c.startingChips
                      + c.rebuysExpected * c.rebuyChips
                      + c.addOnsExpected * c.addOnChips

        // 2. количество уровней
        let plannedLevels = max(2, Int(ceil((c.hours * 60.0) / Double(c.roundMinutes)))) + c.extraLevels

        // 3. стартовый и целевой BB
        let bbStart = max(c.startingSmallBlind * 2, c.smallestDenomination * 2)
        let bbTarget = max(Double(c.startingChips),
                           Double(totalBank) * c.targetBBShareOfBank)

        // 4. средний коэффициент роста
        let growth = pow(bbTarget / Double(bbStart),
                         1.0 / Double(plannedLevels - 1))

        // 5. генерация уровней
        var levels: [BlindLevel] = []
        var prevBB = bbStart

        for i in 0..<plannedLevels {
            // 5.1. следующий BB по геометрической прогрессии
            var bb = i == 0 ? bbStart :
                snapToNice(Int(Double(prevBB) * growth),
                           denom: c.smallestDenomination)

            // гарантируем строгое возрастание
            if bb <= prevBB {
                bb = nextNiceAbove(prev: prevBB,
                                   denom: c.smallestDenomination)
            }

            // 5.2. корректный SB (ровно BB / 2, округляем вверх)
            let sb = snapToDenom(Int((Double(bb) / 2.0).rounded()),
                                 denom: c.smallestDenomination)
            if Double(bb) / Double(sb) > 2.1 {
                bb = snapToDenom(sb * 2, denom: c.smallestDenomination)
            }

            // 5.3. анте (~12% BB, с середины)
            let ante: Int
            if c.useAntes && i >= plannedLevels / 2 {
                let rawAnte = Int(Double(bb) * 0.12)
                ante = snapToDenom(max(rawAnte, c.smallestDenomination),
                                   denom: c.smallestDenomination)
            } else {
                ante = 0
            }

            levels.append(
                BlindLevel(index: i + 1,
                           smallBlind: sb,
                           bigBlind: bb,
                           ante: ante,
                           minutes: c.roundMinutes)
            )

            prevBB = bb
        }
        return levels
    }

    // MARK: - Helpers

    private func snapToDenom(_ value: Int, denom: Int) -> Int {
        let d = max(1, denom)
        let m = (value + d - 1) / d
        return m * d
    }

    /// «красивые» числа: 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10 × 10^k
    private func snapToNice(_ value: Int, denom: Int) -> Int {
        if value <= denom { return denom }
        let v = Double(value)
        let base = pow(10.0, floor(log10(v)))
        let mantissa = v / base
        let stops: [Double] = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
        let chosen = stops.first(where: { mantissa <= $0 }) ?? 10
        let nice = Int((chosen * base).rounded(.up))
        return snapToDenom(nice, denom: denom)
    }

    private func nextNiceAbove(prev: Int, denom: Int) -> Int {
        var candidate = prev + denom
        while true {
            let snapped = snapToNice(candidate, denom: denom)
            if snapped > prev { return snapped }
            candidate += denom
        }
    }
}

// MARK: - Example

#if DEBUG
public func testBlindGenerator() {
    let config = BlindConfig(
        players: 20,
        hours: 5.0,
        roundMinutes: 10,
        smallestDenomination: 10,
        startingChips: 25000,
        startingSmallBlind: 10,
        rebuysExpected: 4,
        rebuyChips: 25000,
        addOnsExpected: 6,
        addOnChips: 25000,
        useAntes: true
    )

    let generator = BlindStructureGenerator()
    let levels = generator.generateLevels(config: config)

    for level in levels {
        print(String(format: "L%02d  %5d / %5d  ante:%4d",
                     level.index, level.smallBlind,
                     level.bigBlind, level.ante))
    }
}
#endif
