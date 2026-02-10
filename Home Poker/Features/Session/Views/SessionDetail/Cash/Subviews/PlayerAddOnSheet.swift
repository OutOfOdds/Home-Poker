import SwiftUI

struct PlayerAddOnSheet: View {
    @Bindable var player: Player
    let session: Session
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var buyInAmount: Int? = nil
    @State private var settleWithBank = false
    @State private var bankContributionAmount: Int? = nil
    
    private var cashRatio: Int {
        max(session.chipsToCashRatio, 1)
    }
    
    private func cashAmount(for chips: Int) -> Int {
        chips * cashRatio
    }
    
    var body: some View {
        FormSheetView(
            title: "Докупка",
            confirmTitle: "Добавить",
            isConfirmDisabled: !canSubmit,
            confirmAction: addOn,
            cancelAction: dismiss.callAsFunction
        ) {
            Form {
                Section("Докупка для \(player.name)") {
                    
                    GroupedIntegerTextField(
                        placeholder: "Сумма докупки",
                        value: $buyInAmount
                    )
                    
                    
                }
                Section {
                    QuickAmountButtons(baseAmount: player.initialBuyIn, selectedAmount: $buyInAmount)
                } footer: {
                    Text("Быстро добавить к сумме докупки")
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
                        Text("Игрок моментально вносит деньги за докупку.")
                    }
                }

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
        guard let amount = buyInAmount, amount > 0 else { return false }
        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return false }
        }
        return true
    }
    
    private func addOn() {
        guard viewModel.addOn(for: player, in: session, amount: buyInAmount) else { return }
        
        if settleWithBank {
            guard let bankAmount = bankContributionAmount, bankAmount > 0 else { return }
            guard viewModel.recordBankDeposit(
                session: session,
                player: player,
                amount: bankAmount,
                note: "Взнос при докупке"
            ) else {
                return
            }
        }
        
        dismiss()
    }
}

#Preview {
    let session = PreviewData.activeSession()
    let player = session.players.first(where: { $0.inGame }) ?? PreviewData.activePlayer()
    
    return PlayerAddOnSheet(player: player, session: session)
        .environment(SessionDetailViewModel())
}

// MARK: - Quick Amount Buttons

private struct QuickAmountButtons: View {
    let baseAmount: Int
    @Binding var selectedAmount: Int?
    @State private var lastTappedMultiplier: Int?
    
    private let multipliers = [1, 2, 3]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(multipliers, id: \.self) { multiplier in
                let increment = baseAmount * multiplier
                Button {
                    selectedAmount = (selectedAmount ?? 0) + increment
                    lastTappedMultiplier = multiplier
                } label: {
                    VStack(spacing: 4) {
                        Text("×\(multiplier)")
                            .font(.caption.bold())
                        Text(formatAmount(increment))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected(multiplier) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .foregroundStyle(isSelected(multiplier) ? .primary : .secondary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    private func isSelected(_ multiplier: Int) -> Bool {
        lastTappedMultiplier == multiplier
    }
    
    private func formatAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
