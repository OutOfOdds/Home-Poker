import SwiftUI

struct BlindsEditorSheet: View {
    let session: Session
    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var smallBlind: Int? = nil
    @State private var bigBlind: Int? = nil
    @State private var ante: Int? = nil
    @State private var bigManuallyEdited = false
    @FocusState private var focusedField: Field?
    private enum Field { case small, big }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Блайнды") {
                    HStack {
                        Text("Small Blind")
                        Spacer()
                        TextField("SB", value: $smallBlind, format: .number)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .small)
                            .keyboardType(.numberPad)
                            .onChange(of: smallBlind) { _, newValue in
                                if !bigManuallyEdited {
                                    bigBlind = newValue.map { $0 * 2 }
                                }
                            }
                    }
                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", value: $bigBlind, format: .number)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .big)
                            .keyboardType(.numberPad)
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big { bigManuallyEdited = true }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", value: $ante, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section {
                    HStack {
                        Text("Итог")
                        Spacer()
                        if let sb = smallBlind, let bb = bigBlind {
                            if let ante = ante, ante > 0 {
                                Text("\(sb)/\(bb) (Анте: \(ante))").foregroundStyle(.secondary)
                            } else {
                                Text("\(sb)/\(bb)").foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Укажите блайнды").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Блайнды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        if viewModel.updateBlinds(for: session, small: smallBlind, big: bigBlind, ante: ante) {
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                smallBlind = session.smallBlind > 0 ? session.smallBlind : nil
                bigBlind = session.bigBlind > 0 ? session.bigBlind : nil
                ante = session.ante > 0 ? session.ante : nil
                bigManuallyEdited = false
            }
        }
    }
    
    private var isValid: Bool {
        guard let sb = smallBlind, let bb = bigBlind else { return false }
        return sb <= bb
    }
}
