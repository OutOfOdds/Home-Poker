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
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(configuration.isOn ? Color.green : .secondary)
                .imageScale(.large)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}
