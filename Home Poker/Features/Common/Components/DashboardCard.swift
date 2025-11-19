//
//  DashboardCard.swift
//  Home Poker
//
//  Базовый компонент карточки для dashboard
//

import SwiftUI

/// Базовая карточка dashboard с настраиваемым контентом
struct DashboardCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color?
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    init(
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 2,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor ?? Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
    }
}

#Preview("Default Card") {
    DashboardCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Title")
                .font(.headline)
            Text("Card content goes here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("Colored Card") {
    DashboardCard(backgroundColor: Color.green.opacity(0.1)) {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Success")
                    .font(.headline)
            }
            Text("Operation completed successfully")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
