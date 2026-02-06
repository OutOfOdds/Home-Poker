import Foundation

enum MoneyFormatter {
    enum Spacing {
        case standard
        case condensed
    }
    
    private static func formatter(for locale: Locale, spacing: Spacing) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.locale = locale
        return formatter
    }
    
    static func format(_ amount: Int, locale: Locale = .current, spacing: Spacing = .condensed) -> String {
        let formatter = formatter(for: locale, spacing: spacing)
        let result = formatter.string(from: amount as NSNumber) ?? "\(amount)"
        return adjustSpacing(in: result, currencySymbol: formatter.currencySymbol, spacing: spacing)
    }
    
    static func format(_ amount: Double, locale: Locale = .current, spacing: Spacing = .condensed) -> String {
        let formatter = formatter(for: locale, spacing: spacing)
        let result = formatter.string(from: amount as NSNumber) ?? "\(Int(amount))"
        return adjustSpacing(in: result, currencySymbol: formatter.currencySymbol, spacing: spacing)
    }
    
    private static func adjustSpacing(in string: String, currencySymbol: String?, spacing: Spacing) -> String {
        guard spacing == .condensed, let symbol = currencySymbol, !symbol.isEmpty else {
            return string
        }
        let nonBreakingSpace = "\u{00A0}"
        return string
            .replacingOccurrences(of: "\(nonBreakingSpace)\(symbol)", with: symbol)
            .replacingOccurrences(of: "\(symbol)\(nonBreakingSpace)", with: symbol)
            .replacingOccurrences(of: " \(symbol)", with: symbol)
            .replacingOccurrences(of: "\(symbol) ", with: symbol)
    }
}

extension Int {
    func asCurrency(locale: Locale = .current, spacing: MoneyFormatter.Spacing = .condensed, showSign: Bool = false) -> String {
        let formatted = MoneyFormatter.format(self, locale: locale, spacing: spacing)
        if showSign && self > 0 {
            return "+\(formatted)"
        }
        return formatted
    }
}
