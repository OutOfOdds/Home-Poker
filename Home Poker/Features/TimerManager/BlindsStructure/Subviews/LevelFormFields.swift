import SwiftUI

/// Локальное состояние формы уровня
struct LevelFormState {
    var smallBlind: String = ""
    var bigBlind: String = ""
    var ante: String = ""
    var minutes: String = ""

    /// Проверяет валидность формы
    var isValid: Bool {
        guard let sb = Int(smallBlind), sb > 0,
              let bb = Int(bigBlind), bb > 0,
              Int(ante) != nil,
              let min = Int(minutes), min > 0
        else {
            return false
        }

        return BlindValidation.validateBlinds(sb: sb, bb: bb) == .valid
    }

    /// Сообщение валидации для отображения
    var validationMessage: String? {
        guard let sb = Int(smallBlind),
              let bb = Int(bigBlind)
        else {
            return nil
        }

        let result = BlindValidation.validateBlinds(sb: sb, bb: bb)
        return result.message
    }

    /// Создаёт BlindLevel из формы
    func createLevel(index: Int) -> BlindLevel? {
        guard isValid,
              let sb = Int(smallBlind),
              let bb = Int(bigBlind),
              let ante = Int(ante),
              let minutes = Int(minutes)
        else {
            return nil
        }

        return BlindLevel(
            index: index,
            smallBlind: sb,
            bigBlind: bb,
            ante: ante,
            minutes: minutes
        )
    }

    /// Загружает данные из существующего уровня
    mutating func load(from level: BlindLevel) {
        smallBlind = String(level.smallBlind)
        bigBlind = String(level.bigBlind)
        ante = String(level.ante)
        minutes = String(level.minutes)
    }

    /// Устанавливает дефолтные значения
    mutating func setDefaults() {
        smallBlind = "100"
        bigBlind = "200"
        ante = "0"
        minutes = "12"
    }

    /// Очищает форму
    mutating func reset() {
        smallBlind = ""
        bigBlind = ""
        ante = ""
        minutes = ""
    }
}

/// Переиспользуемый компонент полей формы уровня
struct LevelFormFields: View {
    @Binding var formState: LevelFormState

    var body: some View {
        Section {
            HStack {
                Text("Small Blind")
                TextField("SB", text: $formState.smallBlind)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 30)
            }

            HStack {
                Text("Big Blind")
                TextField("BB", text: $formState.bigBlind)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Text("Ante")
                Spacer()
                TextField("Ante", text: $formState.ante)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Text("Длительность (мин)")
                Spacer()
                TextField("Минуты", text: $formState.minutes)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
            }
        } footer: {
            if let message = formState.validationMessage {
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var formState = LevelFormState()

    formState.setDefaults()

    return NavigationStack {
        Form {
            LevelFormFields(formState: $formState)
        }
        .navigationTitle("Форма уровня")
    }
}
