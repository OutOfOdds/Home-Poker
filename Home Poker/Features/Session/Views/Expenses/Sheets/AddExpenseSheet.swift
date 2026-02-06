import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let session: Session

    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expenseDescription = ""
    @State private var expenseAmount: Int? = nil
    @State private var payerSelection: AddExpenseSource = .later
    @State private var selectedPayerId: UUID?

    var body: some View {
        FormSheetView(
            title: "Добавить расход",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addExpense,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section {
                    TextField("Описание расхода", text: $expenseDescription)
                        .textInputAutocapitalization(.sentences)

                    GroupedIntegerTextField(
                        placeholder: "Сумма",
                        value: $expenseAmount
                    )

                } header: {
                    Text("Информация о расходе")
                        .font(.caption)
                } footer: {
                    Text("Важено: добавляйте только общие расходы, которые влияют на выплаты между игроками. Личные траты (например, еда для конеретного игрока) не нужно записывать.")
                        .font(.caption)
                }

                Section {
                    Picker("Источник оплаты", selection: $payerSelection) {
                        Text("Указать позже").tag(AddExpenseSource.later)
                        Text("Игрок").tag(AddExpenseSource.player)
                        if canSelectBank {
                            Text("Касса").tag(AddExpenseSource.bank)
                        }
                        if canSelectRake {
                            Text("Рейк").tag(AddExpenseSource.rake)
                        }
                    }
                    
                    if payerSelection == .player {
                        Picker("Оплатил игрок", selection: $selectedPayerId) {
                            ForEach(session.players, id: \.id) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                    } else if payerSelection == .bank {
                        HStack {
                            Text("Доступно в кассе")
                            Spacer()
                            Text(bankBalance.asCurrency())
                                .fontWeight(.semibold)
                        }
                    } else if payerSelection == .rake {
                        HStack {
                            Text("Доступно рейка")
                            Spacer()
                            Text(availableRake.asCurrency())
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Источник оплаты")
                        .font(.caption)
                } footer: {
                    sourceFooter
                }
            }
        }
        .onAppear {
            if selectedPayerId == nil {
                selectedPayerId = session.players.first?.id
            }
        }
    }

    private var canSubmit: Bool {
        guard expenseDescription.nonEmptyTrimmed != nil else { return false }
        guard let amount = expenseAmount, amount > 0 else { return false }
        switch payerSelection {
        case .later:
            return true
        case .player:
            return selectedPayerId != nil
        case .bank:
            return amount <= bankBalance
        case .rake:
            return amount <= availableRake
        }
    }

    private func addExpense() {
        guard let note = expenseDescription.nonEmptyTrimmed else { return }
        let payer = selectedPayer
        guard let expense = viewModel.addExpense(to: session, note: note, amount: expenseAmount, payer: payer) else {
            return
        }

        switch payerSelection {
        case .later:
            break
        case .player:
            break
        case .bank:
            if !viewModel.payExpenseFromBank(expense: expense, amount: expenseAmount, from: session) {
                viewModel.removeExpenses([expense], from: session)
                return
            }
        case .rake:
            expense.paidFromRake = expense.amount
        }
        dismiss()
    }

    private var selectedPayer: Player? {
        guard payerSelection == .player, let id = selectedPayerId else { return nil }
        return session.players.first { $0.id == id }
    }

    private var bankBalance: Int {
        session.bank?.netBalance ?? 0
    }

    private var availableRake: Int {
        viewModel.availableRakeForExpenses(for: session)
    }

    private var canSelectBank: Bool {
        bankBalance > 0
    }

    private var canSelectRake: Bool {
        availableRake > 0
    }

    private var sourceFooter: some View {
        Group {
            switch payerSelection {
            case .later:
                Text("Быстрая запись: источник оплаты и распределение можно указать позже.")
            case .player:
                Text("Выбор игрока влияет на итоговые выплаты.")
            case .bank:
                if let amount = expenseAmount, amount > bankBalance {
                    Text("Недостаточно средств в кассе для полной оплаты.")
                } else {
                    Text("Расход будет оплачен из кассы сразу.")
                }
            case .rake:
                if let amount = expenseAmount, amount > availableRake {
                    Text("Недостаточно рейка для полной оплаты.")
                } else {
                    Text("Расход будет покрыт организаторами.")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddExpenseSheet(session: session)
        .modelContainer(for: [Session.self, Player.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
        .environment(SessionDetailViewModel(service: SessionService()))
}

private enum AddExpenseSource {
    case later
    case player
    case bank
    case rake
}
