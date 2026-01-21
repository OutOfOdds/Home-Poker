import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let session: Session

    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expenseDescription = ""
    @State private var expenseAmount: Int? = nil

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

                    TextField("Сумма", value: $expenseAmount, format: .number)
                        .keyboardType(.numberPad)

                } header: {
                    Text("Информация о расходе")
                        .font(.caption)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard expenseDescription.nonEmptyTrimmed != nil else { return false }
        guard let amount = expenseAmount, amount > 0 else { return false }
        return true
    }

    private func addExpense() {
        guard let note = expenseDescription.nonEmptyTrimmed else { return }
        if viewModel.addExpense(to: session, note: note, amount: expenseAmount, payer: nil) != nil {
            dismiss()
        }
    }
}

#Preview {
    let session = PreviewData.activeSession()

    AddExpenseSheet(session: session)
        .modelContainer(for: [Session.self, Player.self, Expense.self, SessionBank.self, SessionBankTransaction.self], inMemory: true)
        .environment(SessionDetailViewModel(service: SessionService()))
}
