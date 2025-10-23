import SwiftUI
import SwiftData

struct RebuyPlayerSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var rebuyAmount: Int? = nil

    var body: some View {
        FormSheetView(
            title: "Возврат в игру",
            confirmTitle: "Закупить",
            isConfirmDisabled: !canSubmit,
            confirmAction: rebuy,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Возврат игрока \(player.name)")
                            .font(.headline)

                        HStack {
                            Text("Предыдущий результат:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(player.profit.asCurrency())
                                .fontWeight(.semibold)
                                .foregroundStyle(player.profit >= 0 ? .green : .red)
                        }
                        .font(.subheadline)
                    }
                }

                Section("Новая закупка") {
                    TextField("Сумма закупки", value: $rebuyAmount, format: .number)
                        .keyboardType(.numberPad)
                }

                Section {
                    Text("При возврате игрок должен сделать новую закупку. Это новые деньги, которые добавятся в банк сессии.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard let amount = rebuyAmount, amount > 0 else { return false }
        return true
    }

    private func rebuy() {
        if viewModel.rebuyPlayer(player, amount: rebuyAmount, in: session) {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()
    let player = session.players.first(where: { !$0.inGame }) ?? PreviewData.loserPlayer()

    RebuyPlayerSheet(player: player, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
