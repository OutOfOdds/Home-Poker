import SwiftUI
import SwiftData

struct AddExpenseView: View {
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var expenseDescription = ""
    @State private var expenseAmount: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Описание расхода", text: $expenseDescription)
                        .textInputAutocapitalization(.sentences)

                    TextField("Сумма", value: $expenseAmount, format: .number)
                        .keyboardType(.numberPad)
                
                } header: {
                    Text("Информация о расходе")
                        .font(.caption)
                } footer: {
                    Text("Расход будет добавлен в общий котел без указания плательщика. Распределение можно будет выполнить позже.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
            .navigationTitle("Добавить расход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        let note = expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        let expense = Expense(amount: expenseAmount, note: note, createdAt: Date(), payer: nil)
                        session.expenses.append(expense)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        let desc = expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return !desc.isEmpty && expenseAmount > 0
    }
}

#Preview {
    let session = Session(
        startTime: Date(),
        location: "Test Location",
        gameType: .NLHoldem, status: .active
    )
    return AddExpenseView(session: session)
        .modelContainer(for: [Session.self, Player.self, Expense.self], inMemory: true)
}
