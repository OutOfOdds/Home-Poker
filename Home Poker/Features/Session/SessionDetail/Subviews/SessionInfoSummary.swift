import SwiftUI
import SwiftData

struct SessionInfoSummary: View {
    @Bindable var session: Session
    var onEditTapped: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(action: onEditTapped) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    Spacer()
                }
                summaryRow(
                    label: "Сессия:",
                    value: session.sessionTitle.isEmpty ? "Не указано" : session.sessionTitle
                )

                divider

                // Место
                summaryRow(
                    label: "Место:",
                    value: session.location.isEmpty ? "Не указано" : session.location
                )

                divider

                // Начало
                HStack {
                    Text("Начало:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                    Text(session.startTime, format: .dateTime)
                        .font(.headline)
                        .fontDesign(.monospaced)
                }

                divider

                // Тип игры
                summaryRow(
                    label: "Игра:",
                    value: session.gameType.rawValue
                )

                divider

                // Блайнды
                HStack {
                    Text("Блайнды:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                    Text(blindsDisplayText)
                        .font(.headline)
                        .fontDesign(.monospaced)
                }

                divider

                // Номинал фишки
                summaryRow(
                    label: "1 фишка:",
                    value: "\(session.chipsToCashRatio) ₽"
                )
            }
            .italic()
            .fontDesign(.monospaced)
        }
    }

    // MARK: - Helper Views

    private var divider: some View {
        Line()
            .stroke(style: .init(dash: [5]))
            .foregroundStyle(.secondary.opacity(0.5))
            .frame(height: 1)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
            Spacer()
            Text(value)
                .font(.headline)
        }
    }

    private var blindsDisplayText: String {
        if session.smallBlind == 0 && session.bigBlind == 0 && session.ante == 0 {
            return "Не указаны"
        }
        var base = "\(session.smallBlind.asCurrency())/\(session.bigBlind.asCurrency())"
        if session.ante > 0 {
            base += " (Анте: \(session.ante.asCurrency()))"
        }
        return base
    }
}

// MARK: - Preview

#Preview {
    let session = PreviewData.activeSession()

    NavigationStack {
        List {
            SessionInfoSummary(session: session) {
                print("Edit tapped")
            }
        }
        .navigationTitle("Превью информации")
    }
    .modelContainer(
        for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
        inMemory: true
    )
}
