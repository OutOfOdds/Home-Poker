import SwiftUI
import SwiftData

struct RakeAndTipsSheet: View {
    @Bindable var session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var rakeAmount: Int? = nil
    @State private var tipsAmount: Int? = nil

    private var totalDistributed: Int {
        (rakeAmount ?? 0) + (tipsAmount ?? 0)
    }

    private var remainingChips: Int {
        session.chipsInGame
    }

    private var isValid: Bool {
        totalDistributed == remainingChips && totalDistributed >= 0
    }

    private var validationMessage: String? {
        if totalDistributed > remainingChips {
            return "Сумма превышает остаток фишек на столе"
        } else if totalDistributed < remainingChips {
            return "Необходимо распределить ВСЕ фишки. Осталось: \(remainingChips - totalDistributed)"
        }
        return nil
    }

    var body: some View {
        FormSheetView(
            title: "Распределить остатки",
            confirmTitle: "Сохранить",
            isConfirmDisabled: !isValid,
            confirmAction: save,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    HStack {
                        Text("Всего на столе")
                        Spacer()
                        Text("\(remainingChips)")
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .fontDesign(.monospaced)
                    }
                } header: {
                    Text("Остаток фишек")
                }

                Section {
                    HStack {
                        Text("Рейк")
                        Spacer()
                        TextField("0", value: $rakeAmount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .fontDesign(.monospaced)
                    }

                    HStack {
                        Text("Чаевые дилеру")
                        Spacer()
                        TextField("0", value: $tipsAmount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .fontDesign(.monospaced)
                    }

                    HStack {
                        Text("Итого распределено")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(totalDistributed)")
                            .fontWeight(.bold)
                            .foregroundStyle(isValid ? .green : .red)
                            .fontDesign(.monospaced)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Распределение")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Рейк и чаевые объясняют остаток средств в балансе банка и вычитаются из фишек на столе.")
                        if session.chipsToCashRatio > 1 {
                            Text("Конвертация: \(totalDistributed) фишек = \(totalDistributed * session.chipsToCashRatio)₽")
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .onAppear {
            rakeAmount = session.rakeAmount > 0 ? session.rakeAmount : nil
            tipsAmount = session.tipsAmount > 0 ? session.tipsAmount : nil
        }
    }

    private func save() {
        if viewModel.recordRakeAndTips(for: session, rake: rakeAmount ?? 0, tips: tipsAmount ?? 0) {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()

    RakeAndTipsSheet(session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
