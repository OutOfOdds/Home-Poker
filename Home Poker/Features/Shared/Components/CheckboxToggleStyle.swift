//
//  CheckboxToggleStyle.swift
//  Home Poker
//
//  Reusable checkbox toggle style for the entire project
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Color.dynamicColor(value: 1) : .secondary)
                .imageScale(.large)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}
