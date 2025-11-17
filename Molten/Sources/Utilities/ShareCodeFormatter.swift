//
//  ShareCodeFormatter.swift
//  Molten
//
//  Helper for formatting share codes with dashes (ABC-123)
//

import Foundation

extension String {
    /// Format a 6-character share code with dash (e.g., "VHZERC" -> "VHZ-ERC")
    var formattedShareCode: String {
        guard count == 6 else { return self }
        let index = self.index(self.startIndex, offsetBy: 3)
        return String(self[..<index]) + "-" + String(self[index...])
    }

    /// Remove dash from formatted share code (e.g., "VHZ-ERC" -> "VHZERC")
    var unformattedShareCode: String {
        return self.replacingOccurrences(of: "-", with: "")
    }

    /// Validate share code format (6 alphanumeric characters, optionally with dash after 3rd char)
    var isValidShareCode: Bool {
        let unformatted = self.unformattedShareCode
        return unformatted.count == 6 && unformatted.range(of: "^[A-Z0-9]{6}$", options: .regularExpression) != nil
    }
}
