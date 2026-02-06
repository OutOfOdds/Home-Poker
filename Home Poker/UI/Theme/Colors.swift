//
//  Color.swift
//  Home Poker
//
//  Created by Odds on 31.10.2025.
//

import Foundation
import SwiftUI
extension Color {
    static func dynamicColor(value: Int) -> Color {
         value < 0 ? Color(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1)) : Color(#colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1))
    }
}
