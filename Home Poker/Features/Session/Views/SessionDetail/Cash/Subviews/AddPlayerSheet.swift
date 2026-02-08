import SwiftUI
import SwiftData

struct AddPlayerSheet: View {
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClubMemberID: UUID?
    @State private var buyInAmount: Int? = nil
    @State private var settleWithBank = false
    @State private var bankContributionAmount: Int? = nil
    private let statsService = ClubMemberStatsService()

    private var cashRatio: Int {
        max(session.chipsToCashRatio, 1)
    }

    private var clubMembers: [ClubMember] {
        guard let club = session.club else { return [] }
        return club.members.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var availableClubMembers: [ClubMember] {
        let usedMemberIDs = Set(session.players.compactMap(\.clubMemberID))
        let usedNames = Set(session.players.map { $0.name.trimmed.lowercased() })
        return clubMembers.filter { member in
            !usedMemberIDs.contains(member.id) && !usedNames.contains(member.name.lowercased())
        }
    }

    private func cashAmount(for chips: Int) -> Int {
        chips * cashRatio
    }
    
    var body: some View {
        FormSheetView(
            title: "Добавить игрока",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addPlayer,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Участник клуба") {
                    if session.club == nil {
                        Text("Эта сессия не привязана к клубу")
                            .foregroundStyle(.secondary)
                    } else if clubMembers.isEmpty {
                        Text("Пока нет участников в клубе")
                            .foregroundStyle(.secondary)
                    } else if availableClubMembers.isEmpty {
                        Text("Все участники клуба уже добавлены в сессию")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Выбрать участника", selection: $selectedClubMemberID) {
                            Text("Не выбран").tag(Optional<UUID>.none)
                            ForEach(availableClubMembers) { member in
                                Text(member.name).tag(Optional(member.id))
                            }
                        }
                    }
                }

                Section("Информация об игроке") {
                    GroupedIntegerTextField(
                        placeholder: "Сумма закупа",
                        value: $buyInAmount
                    )
                }

                Section {
                    Toggle("Передать наличные в кассу", isOn: $settleWithBank)
                        .onChange(of: settleWithBank) { _, newValue in
                            guard newValue else {
                                bankContributionAmount = nil
                                return
                            }
                            guard let amount = buyInAmount, amount > 0 else {
                                settleWithBank = false
                                return
                            }
                            bankContributionAmount = cashAmount(for: amount)
                        }

                    if settleWithBank {
                        GroupedIntegerTextField(
                            placeholder: "Сумма для банка",
                            value: $bankContributionAmount
                        )
                    }
                } footer: {
                    if settleWithBank {
                        Text("Игрок сразу вносит наличные за закуп.")
                    }
                }
            }
        }
        .onChange(of: availableClubMembers.map(\.id)) { _, ids in
            guard let selected = selectedClubMemberID else { return }
            if !ids.contains(selected) {
                selectedClubMemberID = nil
            }
        }
        .onChange(of: buyInAmount) { _, newValue in
            guard settleWithBank else { return }
            guard let amount = newValue, amount > 0 else {
                settleWithBank = false
                bankContributionAmount = nil
                return
            }
            bankContributionAmount = cashAmount(for: amount)
        }
    }
    
    private var canSubmit: Bool {
        guard selectedClubMemberID != nil else { return false }
        guard let amount = buyInAmount, amount > 0 else { return false }
        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return false }
        }
        return true
    }

    private func addPlayer() {
        guard let selectedID = selectedClubMemberID else { return }
        guard let member = clubMembers.first(where: { $0.id == selectedID }) else { return }

        let name = member.name
        let existingPlayerIDs = Set(session.players.map(\.id))
        guard viewModel.addPlayer(to: session, name: name, buyIn: buyInAmount) else { return }
        let newPlayer = session.players.first(where: { !existingPlayerIDs.contains($0.id) })
            ?? session.players.last(where: { $0.name == name })

        newPlayer?.clubMemberID = member.id

        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return }

            if let player = newPlayer {
                guard viewModel.recordBankDeposit(
                    session: session,
                    player: player,
                    amount: bankAmount,
                    note: "Передал деньги в банк при первичной закупке фишек"
                ) else {
                    statsService.refreshStats(for: session)
                    return
                }
            }
        }

        statsService.refreshStats(for: session)
        dismiss()
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddPlayerSheet(session: session)
        .modelContainer(
            for: [
                Club.self,
                ClubMember.self,
                Session.self,
                Player.self,
                SessionBank.self,
                SessionBankTransaction.self
            ],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
