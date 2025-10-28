//
//  Decimal+Formatting.swift
//  Molten
//
//  Decimal formatting utilities
//

import Foundation

extension Decimal {
    /// Formats the decimal value for display, removing unnecessary trailing zeros
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp

        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    /// Formats the decimal with a specific number of decimal places
    func formatted(decimalPlaces: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.roundingMode = .halfUp

        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
