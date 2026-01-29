import SwiftUI
import SwiftData

struct SessionSearchView: View {

    @Query private var sessions: [Session]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    List {
                        ContentUnavailableView(
                            "Нет сессий",
                            systemImage: "tray",
                            description: Text("Добавьте свою первую сессию")
                        )
                    }
                } else if filteredSessions.isEmpty {
                    List {
                        ContentUnavailableView(
                            "Ничего не найдено",
                            systemImage: "magnifyingglass",
                            description: Text("Попробуйте другое слово")
                        )
                    }
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                sessionRow(session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Поиск")
            .searchable(text: $searchText, placement: .automatic, prompt: "Поиск по сессиям")
        }
    }

    private var filteredSessions: [Session] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sessions }

        return sessions.filter { session in
            session.sessionTitle.localizedCaseInsensitiveContains(trimmed)
            || session.location.localizedCaseInsensitiveContains(trimmed)
            || session.gameType.rawValue.localizedCaseInsensitiveContains(trimmed)
            || session.status.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !session.sessionTitle.isEmpty {
                Text(session.sessionTitle)
                    .font(.title3)
                    .bold()
            }
            HStack(spacing: 8) {
                Text(session.startTime, format: .dateTime)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text("\(session.location)")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text("\(session.gameType.rawValue) | \(session.smallBlind.asCurrency()) / \(session.bigBlind.asCurrency())")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(session.status.rawValue)
                    .font(.footnote.weight(.semibold))
                    .padding(5)
                    .background(statusColor(for: session.status).opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor(for: session.status))
            }
            .glassEffect()
        }
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active: return .green
        case .awaitingForSettlements: return .orange
        case .finished: return .blue
        }
    }
}

#Preview {
    SessionSearchView()
        .modelContainer(PreviewData.previewContainer)
}
