import SwiftUI

struct BlindsEditorSheet: View {
    let session: Session
    
    @Environment(SessionDetailViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var smallText: String = ""
    @State private var bigText: String = ""
    @State private var anteText: String = ""
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
                        TextField("SB", text: $smallText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .small)
                            .onChange(of: smallText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue { smallText = digits; return }
                                if !bigManuallyEdited {
                                    if let sb = Int(digits), sb > 0 {
                                        bigText = String(sb * 2)
                                    } else {
                                        bigText = ""
                                    }
                                }
                            }
                    }
                    HStack {
                        Text("Big Blind")
                        Spacer()
                        TextField("BB", text: $bigText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .big)
                            .onChange(of: bigText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue { bigText = digits }
                            }
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big { bigManuallyEdited = true }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $anteText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .onChange(of: anteText) { _, newValue in
                                let digits = digitsOnly(newValue)
                                if digits != newValue { anteText = digits }
                            }
                    }
                }
                
                Section {
                    HStack {
                        Text("Итог")
                        Spacer()
                        if let sb = Int(smallText), let bb = Int(bigText), sb > 0, bb > 0 {
                            if let ante = Int(anteText), ante > 0 {
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
                        if viewModel.updateBlinds(for: session, smallText: smallText, bigText: bigText, anteText: anteText) {
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                smallText = session.smallBlind > 0 ? String(session.smallBlind) : ""
                bigText = session.bigBlind > 0 ? String(session.bigBlind) : ""
                anteText = session.ante > 0 ? String(session.ante) : ""
                bigManuallyEdited = false
            }
        }
    }
    
    private var isValid: Bool {
        guard let sb = Int(smallText), let bb = Int(bigText) else { return false }
        return sb > 0 && bb > 0 && sb <= bb
    }
    
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}
