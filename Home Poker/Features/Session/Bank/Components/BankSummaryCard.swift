import SwiftUI

struct BankSummaryCard: View {
    let bank: SessionBank
    var backgroundColor: Color? = nil

    private var balanceColor: Color {
        if bank.netBalance > 0 {
            return .green
        } else if bank.netBalance < 0 {
            return .red
        } else {
            return .primary
        }
    }

    var body: some View {
        DashboardCard(backgroundColor: backgroundColor) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "banknote")
                        .foregroundStyle(balanceColor)
                        .font(.title3)
                    Text("Итоги банка")
                        .font(.headline)
                    Spacer()
                }

                // Metrics
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        label: "Получено",
                        value: bank.totalDeposited.asCurrency(),
                        color: .green
                    )

                    MetricRow(
                        label: "Выдано",
                        value: bank.totalWithdrawn.asCurrency(),
                        color: .orange
                    )

                    Divider()

                    MetricRow(
                        label: "Баланс",
                        value: bank.netBalance.asCurrency(),
                        color: balanceColor,
                        isHighlighted: true
                    )
                }
            }
        }
    }
}

/// Вспомогательный компонент для строки метрики
private struct MetricRow: View {
    let label: String
    let value: String
    let color: Color
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isHighlighted ? .body.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(color)
                .monospaced()
        }
    }
}

// MARK: - Previews

#Preview("Positive Balance") {
    let session = PreviewData.sessionWithBank()
    if let bank = session.bank {
        BankSummaryCard(bank: bank)
            .padding()
    }
}

#Preview("Full Bank") {
    let session = PreviewData.sessionWithFullBank()
    if let bank = session.bank {
            BankSummaryCard(bank: bank)
            .padding()
    }
}
