import SwiftUI
import SwiftData

struct ClubMembersView: View {
    @Bindable var club: Club
    @Environment(\.modelContext) private var context
    @State private var showingAddMemberSheet = false
    @State private var memberToDelete: ClubMember?
    @State private var showDeleteConfirmation = false
    private let statsService = ClubMemberStatsService()

    var body: some View {
        membersList
            .navigationTitle("Участники")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMemberSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMemberSheet) {
                AddClubMemberSheet(
                    club: club,
                    existingNames: Set(sortedMembers.map { $0.name.lowercased() })
                )
            }
            .alert("Удалить участника?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) {
                    memberToDelete = nil
                }
                Button("Удалить", role: .destructive) {
                    guard let memberToDelete else { return }
                    deleteMember(memberToDelete)
                    self.memberToDelete = nil
                }
            } message: {
                if let memberToDelete {
                    Text("Участник «\(memberToDelete.name)» будет удален из клуба.")
                }
            }
    }

    private var sortedMembers: [ClubMember] {
        club.members.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var membersList: some View {
        List {
            if sortedMembers.isEmpty {
                ContentUnavailableView(
                    "Нет участников",
                    systemImage: "person.3",
                    description: Text("Добавьте первого участника клуба")
                )
            } else {
                ForEach(sortedMembers) { member in
                    NavigationLink {
                        ClubMemberStatsView(member: member)
                    } label: {
                        Text(member.name)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            memberToDelete = member
                            showDeleteConfirmation = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func deleteMember(_ member: ClubMember) {
        let memberID = member.id
        let descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.clubMemberID == memberID }
        )
        if let players = try? context.fetch(descriptor) {
            players.forEach { $0.clubMemberID = nil }
        }

        statsService.removeStats(for: member, context: context)
        club.members.removeAll { $0.id == member.id }
        context.delete(member)
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to delete member: \(error)")
        }
    }
}

#Preview {
    let container = PreviewData.previewContainer
    let context = container.mainContext
    let club = (try? context.fetch(FetchDescriptor<Club>()).first) ?? Club(name: "Домашний клуб")

    NavigationStack {
        ClubMembersView(club: club)
    }
    .modelContainer(container)
}
