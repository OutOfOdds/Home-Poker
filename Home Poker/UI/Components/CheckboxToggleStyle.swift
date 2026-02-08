//
//  CheckboxToggleStyle.swift
//  Home Poker
//
//  Reusable checkbox toggle style for the entire project
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
                .allowsHitTesting(false)
            configuration.label
            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}
