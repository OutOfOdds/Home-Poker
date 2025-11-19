import SwiftUI
import Observation
import SwiftData

struct SettlementView: View {

    @Bindable var viewModel: SettlementViewModel
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.bankTransfers.isEmpty {
                    bankTransfersSection
                }

                if !viewModel.transfers.isEmpty || viewModel.transfers.isEmpty {
                    playerTransfersSection
                }
            }
            .navigationTitle("Рассчет")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    ShareLink(item: formatSettlementText()) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                // Загружаем или создаем переводы
                loadOrCreateTransfers()
            }
        }
    }


    // MARK: - Bank Transfers Section

    private var bankTransfersSection: some View {
        Section("Операции с кассой") {
            ForEach(Array(viewModel.bankTransfers.enumerated()), id: \.offset) { _, bt in
                let matchedTransfer = viewModel.findMatchingTransfer(for: bt)
                transferRow(
                    fromText: "Из кассы",
                    toText: bt.to.name,
                    amount: bt.amount,
                    color: .green,
                    transfer: matchedTransfer
                )
                .contextMenu {
                    if matchedTransfer?.isCompleted != true {
                        ShareLink(item: formatReminderForBankTransfer(bt)) {
                            Label("Напомнить игроку", systemImage: "bell")
                        }
                    }
                }
            }

            if !viewModel.returnTransfers.isEmpty {
                ForEach(Array(viewModel.returnTransfers.enumerated()), id: \.offset) { _, rt in
                    let matchedTransfer = viewModel.findMatchingTransfer(for: rt)
                    VStack(alignment: .leading, spacing: 4) {
                        transferRow(
                            fromText: rt.from.name,
                            toText: "В кассу",
                            amount: rt.amount,
                            color: .orange,
                            transfer: matchedTransfer
                        )

                        HStack {
                            Spacer()
                            Text(rt.expenseNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        if matchedTransfer?.isCompleted != true {
                            ShareLink(item: formatReminderForReturnTransfer(rt)) {
                                Label("Напомнить игроку", systemImage: "bell")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Player Transfers Section

    private var playerTransfersSection: some View {
        Section("Прямые переводы между игроками") {
            if viewModel.transfers.isEmpty {
                Text("Переводы не требуются")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.transfers.enumerated()), id: \.offset) { _, t in
                    let matchedTransfer = viewModel.findMatchingTransfer(for: t)
                    transferRow(
                        fromText: t.from.name,
                        toText: t.to.name,
                        amount: t.amount,
                        color: .primary,
                        transfer: matchedTransfer
                    )
                    .contextMenu {
                        if matchedTransfer?.isCompleted != true {
                            ShareLink(item: formatReminderForPlayerTransfer(t)) {
                                Label("Напомнить игроку", systemImage: "bell")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Transfer Row

    private func transferRow(
        fromText: String,
        toText: String,
        amount: Int,
        color: Color,
        transfer: SettlementTransfer?
    ) -> some View {
        HStack {
            // Чекбокс (показывается только если перевод сохранен)
            if let transfer = transfer {
                Button {
                    toggleTransfer(transfer)
                } label: {
                    Image(systemName: transfer.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(transfer.isCompleted ? .green : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Text(fromText)
                .foregroundStyle(transfer?.isCompleted == true ? .secondary : .primary)
                .strikethrough(transfer?.isCompleted == true)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Text(toText)
                .foregroundStyle(transfer?.isCompleted == true ? .secondary : .primary)
                .strikethrough(transfer?.isCompleted == true)

            Spacer()

            Text(amount.asCurrency())
                .fontWeight(.semibold)
                .foregroundStyle(transfer?.isCompleted == true ? .secondary : color)
                .strikethrough(transfer?.isCompleted == true)
        }
    }

    // MARK: - Actions

    private func loadOrCreateTransfers() {
        // Загружаем существующие переводы
        viewModel.loadPersistedTransfers(for: session, context: modelContext)

        // Вычисляем ожидаемое количество переводов
        let expectedCount = viewModel.bankTransfers.count +
                            viewModel.returnTransfers.count +
                            viewModel.transfers.count

        // Проверяем актуальность
        if !viewModel.hasPersistedTransfers {
            // Первый раз - создаем переводы
            createTransfers()
        } else if !isSettlementValid(expectedCount: expectedCount) {
            // Данные изменились - пересоздаем
            recreateTransfers()
        } else {
            // Все актуально - используем сохраненные
            print("📋 Loaded existing \(viewModel.persistedTransfers.count) transfers")
        }
    }

    private func isSettlementValid(expectedCount: Int) -> Bool {
        // Проверка 1: Количество переводов
        if viewModel.totalTransfersCount != expectedCount {
            print("⚠️ Transfer count mismatch: expected \(expectedCount), found \(viewModel.totalTransfersCount)")
            return false
        }

        // Проверка 2: Общая сумма переводов
        let expectedTotal = viewModel.bankTransfers.reduce(0) { $0 + $1.amount } +
                            viewModel.returnTransfers.reduce(0) { $0 + $1.amount } +
                            viewModel.transfers.reduce(0) { $0 + $1.amount }

        let persistedTotal = viewModel.persistedTransfers.reduce(0) { $0 + $1.amount }

        if expectedTotal != persistedTotal {
            print("⚠️ Transfer total mismatch: expected \(expectedTotal), found \(persistedTotal)")
            return false
        }

        return true // Все проверки пройдены
    }

    private func createTransfers() {
        do {
            print("💾 Creating transfers for the first time...")
            print("💾 Bank transfers: \(viewModel.bankTransfers.count)")
            print("💾 Return transfers: \(viewModel.returnTransfers.count)")
            print("💾 Player transfers: \(viewModel.transfers.count)")

            try viewModel.saveTransfers(for: session, context: modelContext)

            print("✅ Transfers created!")
            print("✅ Persisted transfers count: \(viewModel.persistedTransfers.count)")
        } catch {
            print("❌ Failed to create transfers: \(error)")
        }
    }

    private func recreateTransfers() {
        do {
            print("🔄 Recreating transfers due to data changes...")
            try viewModel.recreateTransfers(for: session, context: modelContext)
            print("✅ Transfers recreated!")
            print("✅ Persisted transfers count: \(viewModel.persistedTransfers.count)")
        } catch {
            print("❌ Failed to recreate transfers: \(error)")
        }
    }

    private func toggleTransfer(_ transfer: SettlementTransfer) {
        do {
            try viewModel.toggleTransferStatus(transfer, context: modelContext)
            print("✅ Transfer toggled: \(transfer.isCompleted ? "completed" : "incomplete")")
        } catch {
            print("❌ Failed to toggle transfer: \(error)")
        }
    }

    // MARK: - Форматирование напоминаний

    private func formatReminderForPlayerTransfer(_ transfer: TransferProposal) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: session.startTime)

        return """
        Привет, \(transfer.from.name)!

        По итогам игры от \(dateString) нужно совершить перевод:
        Тебе нужно перевести игроку \(transfer.to.name): \(transfer.amount.asCurrency())

        Спасибо!
        """
    }

    private func formatReminderForReturnTransfer(_ transfer: ReturnToBankTransfer) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: session.startTime)

        return """
        Привет, \(transfer.from.name)!

        По итогам игры от \(dateString) нужно совершить перевод:
        Тебе нужно вернуть в кассу: \(transfer.amount.asCurrency())
        (\(transfer.expenseNote))

        Спасибо!
        """
    }

    private func formatReminderForBankTransfer(_ transfer: BankTransfer) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: session.startTime)

        return """
        Привет, \(transfer.to.name)!

        По итогам игры от \(dateString):
        Тебе нужно получить из кассы: \(transfer.amount.asCurrency())

        Спасибо!
        """
    }

    // MARK: - Форматирование текста для шаринга

    private func formatSettlementText() -> String {
        var text = ""

        // Заголовок
        text += "РАСЧЕТ ПО ИГРЕ\n"
        if !session.sessionTitle.isEmpty {
            text += "Название: \(session.sessionTitle)\n"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        text += "Дата: \(dateFormatter.string(from: session.startTime))\n"

        // Выдачи из кассы
        if !viewModel.bankTransfers.isEmpty {
            text += "\nВЫДАЧИ ИЗ КАССЫ:\n"
            for bt in viewModel.bankTransfers {
                let matchedTransfer = viewModel.findMatchingTransfer(for: bt)
                let prefix = matchedTransfer?.isCompleted == true ? "✅ " : "⭕️ "
                text += "\(prefix)Из кассы → \(bt.to.name): \(bt.amount.asCurrency())\n"
            }
        }

        // Возврат в кассу
        if !viewModel.returnTransfers.isEmpty {
            text += "\nВОЗВРАТ В КАССУ:\n"
            for rt in viewModel.returnTransfers {
                let matchedTransfer = viewModel.findMatchingTransfer(for: rt)
                let prefix = matchedTransfer?.isCompleted == true ? "✅ " : "⭕️ "
                text += "\(prefix)\(rt.from.name) → В кассу: \(rt.amount.asCurrency()) (\(rt.expenseNote))\n"
            }
        }

        // Прямые переводы
        text += "\nПРЯМЫЕ ПЕРЕВОДЫ:\n"
        if viewModel.transfers.isEmpty {
            text += "Переводы не требуются\n"
        } else {
            for t in viewModel.transfers {
                let matchedTransfer = viewModel.findMatchingTransfer(for: t)
                let prefix = matchedTransfer?.isCompleted == true ? "✅ " : "⭕️ "
                text += "\(prefix)\(t.from.name) → \(t.to.name): \(t.amount.asCurrency())\n"
            }
        }

        text += "\nСоздано с помощью Home Poker"

        return text
    }
}

#Preview {
    let session = PreviewData.finishedSession()
    let vm = SettlementViewModel(session: session)

    SettlementView(viewModel: vm, session: session)
        .modelContainer(
            for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self, SettlementTransfer.self],
            inMemory: true
        )
}
