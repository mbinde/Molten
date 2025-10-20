//
//  String+Extensions.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//  String utility extensions
//

import Foundation

extension String {
    /// Truncates a SKU string if it exceeds the maximum length
    /// - Parameter maxLength: Maximum allowed length (default: 8)
    /// - Returns: Truncated string with ellipsis if needed, original string otherwise
    func truncatedSKU(maxLength: Int = 8) -> String {
        guard self.count > maxLength else {
            return self
        }
        let truncated = String(self.prefix(maxLength))
        return truncated + "…"
    }
}
