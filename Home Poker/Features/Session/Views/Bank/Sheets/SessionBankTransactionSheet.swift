import SwiftUI
import SwiftData

struct SessionBankTransactionSheet: View {
    @Bindable var session: Session
    let mode: Mode

    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// Для deposit/withdrawal игроку
    @State private var selectedPlayerID: UUID?

    /// Для withdrawal: выбор цели
    @State private var withdrawalPurpose: WithdrawalPurpose = .toPlayer
    @State private var selectedExpenseID: UUID?

    @State private var amount: Int? = nil
    @State private var note: String = ""
    @State private var amountManuallyEdited = false
    @State private var isUpdatingAmount = false


    /// Список игроков отсортированный по имени
    private var players: [Player] {
        session.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Список неоплаченных или частично оплаченных расходов
    private var expenses: [Expense] {
        session.expenses
            .filter { $0.paidFromBank < $0.amount }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Выбранный игрок
    private var selectedPlayer: Player? {
        guard let id = selectedPlayerID else { return nil }
        return players.first(where: { $0.id == id })
    }

    /// Выбранный расход
    private var selectedExpense: Expense? {
        guard let id = selectedExpenseID else { return nil }
        return expenses.first(where: { $0.id == id })
    }

    /// Банк сессии
    private var bank: SessionBank? {
        session.bank
    }

    /// Проверка наличия неоплаченных расходов
    private var hasUnpaidExpenses: Bool {
        !expenses.isEmpty
    }

    /// Проверка наличия неоплаченных чаевых
    private var hasUnpaidTips: Bool {
        guard let bank = session.bank else { return false }
        let unpaidTips = bank.reservedForTips - session.tipsPaidFromBank
        return unpaidTips > 0
    }

    /// Валидация формы
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

    // MARK: - Основной интерфейс

    var body: some View {
        FormSheetView(
            title: mode.title,
            confirmTitle: mode.confirmTitle,
            isConfirmDisabled: !isFormValid,
            confirmAction: submit,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                if mode == .withdrawal {
                    withdrawalPurposeSection
                }

                transactionDetailsSection
            }
        }
        .onAppear {
            initializeForm()
        }
        .onChange(of: withdrawalPurpose) { _, _ in
            handleWithdrawalPurposeChange()
        }
        .onChange(of: selectedExpenseID) { _, _ in
            handleExpenseSelectionChange()
        }
    }

    // MARK: - Компоненты интерфейса

    /// Секция выбора цели выдачи денег
    @ViewBuilder
    private var withdrawalPurposeSection: some View {
        Section("Цель выдачи") {
            Picker("Тип", selection: $withdrawalPurpose) {
                Text("Игроку").tag(WithdrawalPurpose.toPlayer)

                if hasUnpaidExpenses {
                    Text("Оплата расхода").tag(WithdrawalPurpose.forExpense)
                }

                if hasUnpaidTips {
                    Text("Чаевые дилеру").tag(WithdrawalPurpose.forTips)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Основная секция с деталями транзакции
    @ViewBuilder
    private var transactionDetailsSection: some View {
        Section {
            targetSelectionView
            amountField
            noteField
        } footer: {
            footerContent
        }
    }

    /// Выбор цели транзакции (игрок/расход/чаевые)
    @ViewBuilder
    private var targetSelectionView: some View {
        if mode == .deposit || withdrawalPurpose == .toPlayer {
            playerPickerView
        } else if withdrawalPurpose == .forExpense {
            expensePickerView
        } else if withdrawalPurpose == .forTips {
            tipsInfoView
        }
    }

    /// Выбор игрока с информацией
    @ViewBuilder
    private var playerPickerView: some View {
        Picker("Игрок", selection: playerBinding) {
            ForEach(players, id: \.id) { player in
                Text(player.name).tag(Optional(player.id))
            }
        }
    }

    /// Выбор расхода с информацией
    @ViewBuilder
    private var expensePickerView: some View {
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

            if let expense = selectedExpense {
                expenseDetailsView(expense)
            }
        }
    }

    /// Детальная информация о выбранном расходе
    @ViewBuilder
    private func expenseDetailsView(_ expense: Expense) -> some View {
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

    /// Информация о чаевых
    @ViewBuilder
    private var tipsInfoView: some View {
        Text("Выдача денег на чаевые дилеру")
            .foregroundStyle(.secondary)
            .font(.callout)
    }

    /// Поле ввода суммы
    @ViewBuilder
    private var amountField: some View {
        TextField("Сумма", value: $amount, format: .number)
            .keyboardType(.numberPad)
            .onChange(of: amount) { _, _ in
                handleAmountChange()
            }
    }

    /// Поле ввода заметки
    @ViewBuilder
    private var noteField: some View {
        TextField("Заметка (опционально)", text: $note, axis: .vertical)
    }

    /// Футер с дополнительной информацией
    private var footerContent: some View {
        Group {
            if let bank {
                VStack(alignment: .leading, spacing: 4) {
                    // Информация об игроке
                    if let player = selectedPlayer, (mode == .deposit || withdrawalPurpose == .toPlayer) {
                        playerInfoView(player: player, bank: bank)
                        Divider()
                    }

                    // Общая информация о банке
                    bankInfoView(bank)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Информация об игроке
    @ViewBuilder
    private func playerInfoView(player: Player, bank: SessionBank) -> some View {
        let contributions = bank.contributions(for: player)
        let deposited = contributions.deposited
        let withdrawn = contributions.withdrawn

        Text("Игрок внёс: \(deposited.asCurrency())")
            .monospaced()
        Text("Игроку выдано: \(withdrawn.asCurrency())")
            .monospaced()

        switch mode {
        case .deposit:
            playerDepositInfo(player: player, bank: bank)
        case .withdrawal:
            playerWithdrawalInfo(deposited: deposited, withdrawn: withdrawn)
        }
    }

    /// Информация при пополнении от игрока
    @ViewBuilder
    private func playerDepositInfo(player: Player, bank: SessionBank) -> some View {
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
    }

    /// Информация при выдаче игроку
    @ViewBuilder
    private func playerWithdrawalInfo(deposited: Int, withdrawn: Int) -> some View {
        let available = max(deposited - withdrawn, 0)
        Text("Доступно к выдаче: \(available.asCurrency())")
            .foregroundStyle(.secondary)
            .monospaced()
    }

    /// Общая информация о банке
    @ViewBuilder
    private func bankInfoView(_ bank: SessionBank) -> some View {
        Text("В банке: \(bank.netBalance.asCurrency())")
            .monospaced()
        Text("Получено: \(bank.totalDeposited.asCurrency())")
            .monospaced()
        Text("Осталось собрать: \(bank.remainingToCollect.asCurrency())")
            .monospaced()
    }

    // MARK: - Вспомогательные методы

    /// Отправка формы
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

    /// Инициализация формы при открытии
    private func initializeForm() {
        viewModel.ensureBank(for: session)

        if selectedPlayerID == nil {
            selectedPlayerID = mode == .deposit
            ? session.bank?.manager?.id ?? players.first?.id
            : players.first?.id
        }

        if selectedExpenseID == nil {
            selectedExpenseID = expenses.first?.id
        }

        if mode == .withdrawal {
            resetWithdrawalPurposeIfNeeded()
        }

        updateSuggestedAmountIfNeeded(force: true)
    }

    /// Обработка изменения цели выдачи
    private func handleWithdrawalPurposeChange() {
        updateNoteForPurpose()
        updateSuggestedAmountIfNeeded(force: true)
    }

    /// Обработка изменения выбранного расхода
    private func handleExpenseSelectionChange() {
        updateNoteForPurpose()
        updateSuggestedAmountIfNeeded(force: true)
    }

    /// Обработка изменения суммы пользователем
    private func handleAmountChange() {
        guard !isUpdatingAmount else { return }
        amountManuallyEdited = true
    }

    /// Binding для выбора игрока
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

    /// Binding для выбора расхода
    private var expenseBinding: Binding<UUID?> {
        Binding(
            get: { selectedExpenseID },
            set: {
                selectedExpenseID = $0
                amountManuallyEdited = false
            }
        )
    }

    /// Вычисление оставшейся суммы расхода
    private func expenseRemainingAmount(_ expense: Expense) -> Int {
        max(expense.amount - expense.paidFromBank, 0)
    }

    /// Обновление заметки в зависимости от цели
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

    /// Сброс цели выдачи если она стала недоступной
    private func resetWithdrawalPurposeIfNeeded() {
        switch withdrawalPurpose {
        case .forExpense:
            if !hasUnpaidExpenses {
                withdrawalPurpose = .toPlayer
            }
        case .forTips:
            if !hasUnpaidTips {
                withdrawalPurpose = .toPlayer
            }
        case .toPlayer:
            break
        }
    }

    /// Обновление предлагаемой суммы
    private func updateSuggestedAmountIfNeeded(force: Bool) {
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
                amount = nil
            case .forExpense:
                if let expense = selectedExpense {
                    amount = expenseRemainingAmount(expense)
                }
            case .forTips:
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

// MARK: - Вспомогательные типы

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
