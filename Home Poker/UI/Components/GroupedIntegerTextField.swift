import SwiftUI
import UIKit

struct GroupedIntegerTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var value: Int?

    var keyboardType: UIKeyboardType = .numberPad
    var usesGrouping: Bool = true
    var groupingSeparator: String = Locale.current.groupingSeparator ?? " "
    var minValue: Int? = nil
    var maxValue: Int? = nil
    var borderStyle: UITextField.BorderStyle = .none
    var onEditingChanged: ((Bool) -> Void)? = nil

    init(
        placeholder: String,
        value: Binding<Int?>,
        keyboardType: UIKeyboardType = .numberPad,
        usesGrouping: Bool = true,
        groupingSeparator: String = Locale.current.groupingSeparator ?? " ",
        minValue: Int? = nil,
        maxValue: Int? = nil,
        borderStyle: UITextField.BorderStyle = .none,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._value = value
        self.keyboardType = keyboardType
        self.usesGrouping = usesGrouping
        self.groupingSeparator = groupingSeparator
        self.minValue = minValue
        self.maxValue = maxValue
        self.borderStyle = borderStyle
        self.onEditingChanged = onEditingChanged
    }

    init(
        placeholder: String,
        value: Binding<Int>,
        keyboardType: UIKeyboardType = .numberPad,
        usesGrouping: Bool = true,
        groupingSeparator: String = Locale.current.groupingSeparator ?? " ",
        minValue: Int? = nil,
        maxValue: Int? = nil,
        borderStyle: UITextField.BorderStyle = .none,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._value = Binding<Int?>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = $0 ?? 0 }
        )
        self.keyboardType = keyboardType
        self.usesGrouping = usesGrouping
        self.groupingSeparator = groupingSeparator
        self.minValue = minValue
        self.maxValue = maxValue
        self.borderStyle = borderStyle
        self.onEditingChanged = onEditingChanged
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.textAlignment = .natural
        textField.borderStyle = borderStyle
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.text = context.coordinator.formattedText(for: value)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.borderStyle = borderStyle

        if context.coordinator.isApplyingChange {
            return
        }

        let expectedText = context.coordinator.formattedText(for: value)
        guard uiView.text != expectedText else { return }

        if uiView.isFirstResponder {
            // Allow external state changes (e.g. quick amount shortcuts) to override current input.
            let currentValue = context.coordinator.intValue(from: uiView.text ?? "")
            if currentValue != value {
                uiView.text = expectedText
                context.coordinator.moveCursorToEnd(in: uiView)
            }
            return
        }

        uiView.text = expectedText
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            value: $value,
            usesGrouping: usesGrouping,
            groupingSeparator: groupingSeparator,
            minValue: minValue,
            maxValue: maxValue,
            onEditingChanged: onEditingChanged
        )
    }
}

extension GroupedIntegerTextField {
    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var value: Int?
        private let formatter: NumberFormatter
        private let minValue: Int?
        private let maxValue: Int?
        private let onEditingChanged: ((Bool) -> Void)?
        var isApplyingChange = false

        init(
            value: Binding<Int?>,
            usesGrouping: Bool,
            groupingSeparator: String,
            minValue: Int?,
            maxValue: Int?,
            onEditingChanged: ((Bool) -> Void)?
        ) {
            _value = value
            self.minValue = minValue
            self.maxValue = maxValue
            self.onEditingChanged = onEditingChanged

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            formatter.usesGroupingSeparator = usesGrouping
            formatter.groupingSize = 3
            formatter.groupingSeparator = groupingSeparator
            formatter.locale = Locale.current
            self.formatter = formatter
        }

        @objc
        func textDidChange(_ textField: UITextField) {
            guard !isApplyingChange else { return }
            isApplyingChange = true
            defer { isApplyingChange = false }

            let text = textField.text ?? ""
            let cursorOffset = selectedOffset(in: textField)
            let digitsBeforeCursor = countDigits(in: String(text.prefix(cursorOffset)))
            let digits = digitsOnly(from: text)

            guard !digits.isEmpty else {
                value = nil
                textField.text = ""
                setCursor(in: textField, digitOffset: 0)
                return
            }

            guard var intValue = Int(digits) else {
                textField.text = formattedText(for: value)
                setCursor(in: textField, digitOffset: digitsBeforeCursor)
                return
            }

            if let minValue {
                intValue = max(intValue, minValue)
            }
            if let maxValue {
                intValue = min(intValue, maxValue)
            }

            value = intValue
            textField.text = formattedText(for: value)
            setCursor(in: textField, digitOffset: digitsBeforeCursor)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged?(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            onEditingChanged?(false)
        }

        func formattedText(for value: Int?) -> String {
            guard let value else { return "" }
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        func intValue(from text: String) -> Int? {
            let digits = digitsOnly(from: text)
            guard !digits.isEmpty else { return nil }
            return Int(digits)
        }

        func moveCursorToEnd(in textField: UITextField) {
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
        }

        private func selectedOffset(in textField: UITextField) -> Int {
            guard let selectedRange = textField.selectedTextRange else {
                return textField.text?.count ?? 0
            }
            let offset = textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
            return max(0, offset)
        }

        private func setCursor(in textField: UITextField, digitOffset: Int) {
            let text = textField.text ?? ""
            let targetCharacterOffset = characterOffset(forDigitOffset: digitOffset, in: text)

            guard let start = textField.position(from: textField.beginningOfDocument, offset: targetCharacterOffset) else {
                return
            }
            textField.selectedTextRange = textField.textRange(from: start, to: start)
        }

        private func characterOffset(forDigitOffset digitOffset: Int, in text: String) -> Int {
            guard digitOffset > 0 else { return 0 }

            var digitCount = 0
            for (index, character) in text.enumerated() {
                if character.isWholeNumber {
                    digitCount += 1
                    if digitCount == digitOffset {
                        return index + 1
                    }
                }
            }

            return text.count
        }

        private func digitsOnly(from text: String) -> String {
            text.filter(\.isWholeNumber)
        }

        private func countDigits(in text: String) -> Int {
            text.reduce(into: 0) { result, character in
                if character.isWholeNumber {
                    result += 1
                }
            }
        }
    }
}
