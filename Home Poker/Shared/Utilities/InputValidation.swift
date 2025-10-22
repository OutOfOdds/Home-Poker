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

}
