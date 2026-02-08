import SwiftUI
import SwiftData

struct ClubListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Club.createdAt, order: .reverse)]) private var clubs: [Club]
    @State private var showingCreateClubSheet = false
    @State private var clubToDelete: Club?
    @State private var showDeleteConfirmation = false
    private let statsService = ClubMemberStatsService()

    var body: some View {
        NavigationStack {
            clubList
                .navigationTitle("Клубы")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreateClubSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Создать")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingCreateClubSheet) {
                    CreateClubSheet(
                        existingNames: Set(clubs.map { $0.name.lowercased() })
                    )
                }
                .alert("Удалить клуб?", isPresented: $showDeleteConfirmation) {
                    Button("Отмена", role: .cancel) {
                        clubToDelete = nil
                    }
                    Button("Удалить", role: .destructive) {
                        if let clubToDelete {
                            deleteClub(clubToDelete)
                            self.clubToDelete = nil
                        }
                    }
                } message: {
                    if let clubToDelete {
                        Text("\nКлуб «\(clubToDelete.name)» будет удален вместе со всеми сессиями и участниками.\n\nЭто действие нельзя отменить.")
                    }
                }
        }
    }

    private var clubList: some View {
        List {
            if clubs.isEmpty {
                ContentUnavailableView(
                    "Нет клубов",
                    systemImage: "building.2",
                    description: Text("Создайте первый клуб, чтобы начать вести сессии")
                )
            } else {
                ForEach(clubs) { club in
                    NavigationLink {
                        ClubSessionsView(club: club)
                    } label: {
                        clubRow(club)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            clubToDelete = club
                            showDeleteConfirmation = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func clubRow(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(club.name)
                .font(.headline)

            Text("Сессий: \(club.sessions.count) · Участников: \(club.members.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func deleteClub(_ club: Club) {
        statsService.removeStats(for: club, context: context)
        context.delete(club)
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to delete club: \(error)")
        }
    }
}

#Preview {
    ClubListView()
        .modelContainer(PreviewData.previewContainer)
}
