import Foundation
import SwiftUI

extension String {
    /// Removes whitespaces and newlines from both ends.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns a trimmed string or nil when the result is empty.
    var nonEmptyTrimmed: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    /// Returns only numeric characters.
    var digitsOnly: String {
        filter(\.isNumber)
    }

    /// Parses the string into a positive integer.
    var positiveInt: Int? {
        guard let value = Int(self), value > 0 else { return nil }
        return value
    }

    /// Parses the string into a non-negative integer.
    var nonNegativeInt: Int? {
        guard let value = Int(self), value >= 0 else { return nil }
        return value
    }
}

extension Binding where Value == String {
    /// Ensures only digits are written into the binding.
    func digitsOnly() -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0.digitsOnly }
        )
    }
}
