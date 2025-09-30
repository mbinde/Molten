import Foundation

/// A structure that maps glass manufacturer shorthand codes to their full company names
struct GlassManufacturers {
    
    /// Static mapping of manufacturer shorthand codes to full names
    static let manufacturers: [String: String] = [
        "EF": "Effetre",
        "DH": "Double Helix",
        "BB": "Boro Batch",
        "CiM": "Creation is Messy",
        "GA": "Glass Alchemy",
        "RE": "Reichenbach",
        "TAG": "Trautmann Art Glass",
        "VF": "Vetrofond",
        "NS": "Northstar Glassworks"
    ]
    
    /// Get the full manufacturer name from a shorthand code
    /// - Parameter code: The shorthand manufacturer code (e.g., "EF", "DH")
    /// - Returns: The full manufacturer name, or nil if the code is not found
    static func fullName(for code: String) -> String? {
        return manufacturers[code]
    }
    
    /// Get all available manufacturer codes
    /// - Returns: An array of all shorthand codes
    static var allCodes: [String] {
        return Array(manufacturers.keys).sorted()
    }
    
    /// Get all manufacturer full names
    /// - Returns: An array of all full manufacturer names
    static var allNames: [String] {
        return Array(manufacturers.values).sorted()
    }
    
    /// Check if a manufacturer code exists
    /// - Parameter code: The shorthand code to check
    /// - Returns: True if the code exists, false otherwise
    static func isValid(code: String) -> Bool {
        return manufacturers[code] != nil
    }
}

// MARK: - Usage Examples
extension GlassManufacturers {
    
    /// Example usage demonstrating how to use the manufacturer mapping
    static func examples() {
        // Get full name from code
        if let fullName = GlassManufacturers.fullName(for: "EF") {
            print("EF stands for: \(fullName)")
        }
        
        // Check if code is valid
        let isValid = GlassManufacturers.isValid(code: "DH")
        print("DH is a valid code: \(isValid)")
        
        // Get all codes
        let allCodes = GlassManufacturers.allCodes
        print("Available codes: \(allCodes.joined(separator: ", "))")
    }
}