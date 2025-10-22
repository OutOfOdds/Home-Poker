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
                        TextField("SB", text: $smallText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .small)
                            .onChange(of: smallText) { _, newValue in
                                if !bigManuallyEdited {
                                    if let sb = newValue.positiveInt {
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
                        TextField("BB", text: $bigText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .big)
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .big { bigManuallyEdited = true }
                    }
                    HStack {
                        Text("Ante")
                        Spacer()
                        TextField("Ante", text: $anteText.digitsOnly())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section {
                    HStack {
                        Text("Итог")
                        Spacer()
                        if let sb = smallText.positiveInt, let bb = bigText.positiveInt {
                            if let ante = anteText.nonNegativeInt, ante > 0 {
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
        guard let sb = smallText.positiveInt, let bb = bigText.positiveInt else { return false }
        return sb <= bb
    }
}
