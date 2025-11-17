import SwiftUI
import SwiftData

struct SessionBankTransactionSheet: View {
    @Bindable var session: Session
    let mode: Mode

    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    // Для deposit/withdrawal игроку
    @State private var selectedPlayerID: UUID?

    // Для withdrawal: выбор цели
    @State private var withdrawalPurpose: WithdrawalPurpose = .toPlayer
    @State private var selectedExpenseID: UUID?

    @State private var amount: Int? = nil
    @State private var note: String = ""
    @State private var amountManuallyEdited = false
    @State private var isUpdatingAmount = false

    private var players: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var expenses: [Expense] {
        session.expenses
            .filter { $0.paidFromBank + $0.paidFromRake < $0.amount }  // Только неоплаченные/частично оплаченные
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var selectedPlayer: Player? {
        guard let id = selectedPlayerID else { return nil }
        return players.first(where: { $0.id == id })
    }

    private var selectedExpense: Expense? {
        guard let id = selectedExpenseID else { return nil }
        return expenses.first(where: { $0.id == id })
    }

    private var bank: SessionBank? {
        session.bank
    }

    private var hasAvailableRakeForExpenses: Bool {
        guard let bank = session.bank else { return false }
        // Показываем опцию только если есть доступный рейк И есть неоплаченные расходы
        return bank.availableRakeForExpenses > 0 && !expenses.isEmpty
    }

    private var hasUnpaidTips: Bool {
        guard let bank = session.bank else { return false }
        let unpaidTips = bank.reservedForTips - session.tipsPaidFromBank
        return unpaidTips > 0
    }

    private var isFormValid: Bool {
        guard let amount, amount > 0 else { return false }

        // Проверка наличия средств в банке ТОЛЬКО для выдачи денег
        if mode == .withdrawal, let bank, amount > bank.netBalance {
            return false
        }

        // Проверка в зависимости от типа операции
        if mode == .deposit {
            return selectedPlayer != nil
        } else {
            // withdrawal
            switch withdrawalPurpose {
            case .toPlayer:
                return selectedPlayer != nil
            case .forExpense:
                return selectedExpense != nil
            case .forTips:
                return true
            }
        }
    }

    var body: some View {
        FormSheetView(
            title: mode.title,
            confirmTitle: mode.confirmTitle,
            isConfirmDisabled: !isFormValid,
            confirmAction: submit,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                // Для withdrawal добавляем выбор цели
                if mode == .withdrawal {
                    Section("Цель выдачи") {
                        Picker("Тип", selection: $withdrawalPurpose) {
                            Text("Игроку").tag(WithdrawalPurpose.toPlayer)

                            // Показываем только если есть доступный рейк для покрытия расходов
                            if hasAvailableRakeForExpenses {
                                Text("Оплата расхода").tag(WithdrawalPurpose.forExpense)
                            }

                            // Показываем только если есть неоплаченные чаевые
                            if hasUnpaidTips {
                                Text("Чаевые дилеру").tag(WithdrawalPurpose.forTips)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Детали операции
                Section {
                    if mode == .deposit || withdrawalPurpose == .toPlayer {
                        // Выбор игрока
                        Picker("Игрок", selection: playerBinding) {
                            ForEach(players, id: \.id) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                    } else if withdrawalPurpose == .forExpense {
                        // Выбор расхода
                        if expenses.isEmpty {
                            Text("Нет неоплаченных расходов")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Расход", selection: expenseBinding) {
                                ForEach(expenses, id: \.id) { expense in
                                    HStack {
                                        Text(expense.note.isEmpty ? "Расход" : expense.note)
                                        Spacer()
                                        Text(expenseRemainingAmount(expense).asCurrency())
                                    }
                                    .tag(Optional(expense.id))
                                }
                            }

                            // Показать информацию о выбранном расходе
                            if let expense = selectedExpense {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Сумма расхода")
                                        Spacer()
                                        Text(expense.amount.asCurrency())
                                            .monospaced()
                                    }
                                    HStack {
                                        Text("Уже оплачено")
                                        Spacer()
                                        Text(expense.paidFromBank.asCurrency())
                                            .monospaced()
                                            .foregroundStyle(.green)
                                    }
                                    HStack {
                                        Text("Осталось")
                                        Spacer()
                                        Text(expenseRemainingAmount(expense).asCurrency())
                                            .monospaced()
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else if withdrawalPurpose == .forTips {
                        // Для чаевых просто показываем информацию
                        Text("Выдача денег на чаевые дилеру")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }

                    // Сумма
                    TextField("Сумма", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .onChange(of: amount) { _, _ in
                            guard !isUpdatingAmount else { return }
                            amountManuallyEdited = true
                        }

                    // Примечание
                    TextField("Заметка (опционально)", text: $note, axis: .vertical)
                } footer: {
                    footerContent
                }
            }
        }
        .onAppear {
            viewModel.ensureBank(for: session)
            if selectedPlayerID == nil {
                selectedPlayerID = mode == .deposit
                ? session.bank?.manager?.id ?? players.first?.id
                : players.first?.id
            }
            if selectedExpenseID == nil {
                selectedExpenseID = expenses.first?.id
            }

            // Сбрасываем выбранную цель withdrawal, если она стала недоступной
            if mode == .withdrawal {
                resetWithdrawalPurposeIfNeeded()
            }

            updateSuggestedAmountIfNeeded(force: true)
        }
        .onChange(of: withdrawalPurpose) { _, _ in
            updateNoteForPurpose()
            updateSuggestedAmountIfNeeded(force: true)
        }
        .onChange(of: selectedExpenseID) { _, _ in
            updateNoteForPurpose()
            updateSuggestedAmountIfNeeded(force: true)
        }
    }

    private func submit() {
        guard isFormValid else { return }

        let didSucceed: Bool
        if mode == .deposit, let player = selectedPlayer {
            didSucceed = viewModel.recordBankDeposit(session: session, player: player, amount: amount, note: note)
        } else {
            // withdrawal
            switch withdrawalPurpose {
            case .toPlayer:
                guard let player = selectedPlayer else { return }
                didSucceed = viewModel.recordBankWithdrawal(session: session, player: player, amount: amount, note: note)

            case .forExpense:
                guard let expense = selectedExpense else { return }
                didSucceed = viewModel.payExpenseFromBank(expense: expense, amount: amount, from: session)

            case .forTips:
                didSucceed = viewModel.payTipsFromBank(amount: amount, for: session)
            }
        }

        if didSucceed {
            dismiss()
        }
    }

    private var playerBinding: Binding<UUID?> {
        Binding(
            get: { selectedPlayerID },
            set: {
                selectedPlayerID = $0
                amountManuallyEdited = false
                updateSuggestedAmountIfNeeded(force: false)
            }
        )
    }

    private var expenseBinding: Binding<UUID?> {
        Binding(
            get: { selectedExpenseID },
            set: {
                selectedExpenseID = $0
                amountManuallyEdited = false
            }
        )
    }

    private func expenseRemainingAmount(_ expense: Expense) -> Int {
        max(expense.amount - expense.paidFromBank, 0)
    }

    private func updateNoteForPurpose() {
        guard mode == .withdrawal else { return }

        switch withdrawalPurpose {
        case .toPlayer:
            note = ""
        case .forExpense:
            if let expense = selectedExpense {
                note = "Расход: \(expense.note)"
            }
        case .forTips:
            note = "Чаевые дилеру"
        }
    }

    private var footerContent: some View {
        Group {
            if let bank {
                VStack(alignment: .leading, spacing: 4) {
                    // Для deposit или withdrawal игроку показываем информацию об игроке
                    if let player = selectedPlayer, (mode == .deposit || withdrawalPurpose == .toPlayer) {
                        let contributions = bank.contributions(for: player)
                        let deposited = contributions.deposited
                        let withdrawn = contributions.withdrawn
                        Text("Игрок внёс: \(deposited.asCurrency())")
                            .monospaced()
                        Text("Игроку выдано: \(withdrawn.asCurrency())")
                            .monospaced()

                        switch mode {
                        case .deposit:
                            let result = bank.financialResult(for: player)
                            let bankOwes = max(result, 0)
                            let playerOwes = max(-result, 0)

                            if bankOwes > 0 {
                                if player.chipProfit > 0 {
                                    Text("Игрок выиграл: \(bankOwes.asCurrency())")
                                        .foregroundStyle(.green)
                                        .monospaced()
                                } else {
                                    Text("Переплата: \(bankOwes.asCurrency())")
                                        .foregroundStyle(.blue)
                                        .monospaced()
                                }
                            } else if playerOwes > 0 {
                                Text("Осталось внести: \(playerOwes.asCurrency())")
                                    .foregroundStyle(.secondary)
                                    .monospaced()
                            } else {
                                Text("Расчёты закрыты")
                                    .foregroundStyle(.secondary)
                            }
                        case .withdrawal:
                            let available = max(deposited - withdrawn, 0)
                            Text("Доступно к выдаче: \(available.asCurrency())")
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }

                        Divider()
                    }

                    // Общая информация о банке
                    Text("В банке: \(bank.netBalance.asCurrency())")
                        .monospaced()
                    Text("Получено: \(bank.totalDeposited.asCurrency())")
                        .monospaced()
                    Text("Осталось собрать: \(bank.remainingToCollect.asCurrency())")
                        .monospaced()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func resetWithdrawalPurposeIfNeeded() {
        // Если выбранная цель withdrawal стала недоступной, сбрасываем на .toPlayer
        switch withdrawalPurpose {
        case .forExpense:
            if !hasAvailableRakeForExpenses {
                withdrawalPurpose = .toPlayer
            }
        case .forTips:
            if !hasUnpaidTips {
                withdrawalPurpose = .toPlayer
            }
        case .toPlayer:
            break  // Всегда доступно
        }
    }

    private func updateSuggestedAmountIfNeeded(force: Bool) {
        // Обновляем сумму если:
        // - force = true (при первом открытии)
        // - пользователь не редактировал сумму вручную после смены игрока/расхода
        guard force || !amountManuallyEdited else { return }
        guard let bank else { return }

        isUpdatingAmount = true
        defer {
            DispatchQueue.main.async {
                self.isUpdatingAmount = false
            }
        }

        if mode == .deposit, let player = selectedPlayer {
            let playerOwes = max(-bank.financialResult(for: player), 0)
            amount = playerOwes > 0 ? playerOwes : nil
        } else if mode == .withdrawal {
            switch withdrawalPurpose {
            case .toPlayer:
                amount = nil  // Не подсказываем сумму для выдачи игроку
            case .forExpense:
                if let expense = selectedExpense {
                    amount = expenseRemainingAmount(expense)
                }
            case .forTips:
                // Автозаполняем суммой зарезервированных чаевых минус уже выплаченные
                let tipsReserved = bank.reservedForTips
                let tipsPaid = session.tipsPaidFromBank
                let tipsRemaining = max(tipsReserved - tipsPaid, 0)
                amount = tipsRemaining > 0 ? tipsRemaining : nil
            }
        }

        if force {
            amountManuallyEdited = false
        }
    }
}

enum Mode {
    case deposit
    case withdrawal

    var title: String {
        switch self {
        case .deposit:
            return "Принять взнос"
        case .withdrawal:
            return "Выдать деньги"
        }
    }

    var confirmTitle: String {
        switch self {
        case .deposit:
            return "Принять"
        case .withdrawal:
            return "Выдать"
        }
    }
}

enum WithdrawalPurpose {
    case toPlayer       // Выдача игроку
    case forExpense     // Оплата расхода
    case forTips        // Оплата чаевых
}

#Preview {
    let session = PreviewData.sessionWithBank()

    return SessionBankTransactionSheet(session: session, mode: .deposit)
        .modelContainer(
            for: [Session.self, Player.self, PlayerChipTransaction.self, Expense.self, SessionBank.self, SessionBankTransaction.self],
            inMemory: true
        )
        .environment(SessionDetailViewModel())
}
