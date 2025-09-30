import Foundation
import SwiftUI

/// A structure that manages glass manufacturer information including name mappings and colors
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
        "NS": "Northstar Glassworks",
        "BE": "Bullseye",
    ]
    
    /// Static mapping of manufacturer codes to their COE (Coefficient of Expansion) values
    static let manufacturerCOEs: [String: [Int]] = [
        "BB": [33],           // Boro Batch makes 33
        "NS": [33],           // Northstar Glassworks makes 33
        "CiM": [33],          // Creation is Messy makes 33
        "GA": [33],           // Glass Alchemy makes 33
        "TAG": [33, 104],     // Trautmann Art Glass makes both 33 and 104
        "BE": [90],           // Bullseye makes 90
        "EF": [104],          // Effetre makes 104
        "DH": [104],          // Double Helix makes 104
        "RE": [104],          // Reichenbach makes 104
        "VF": [104],          // Vetrofond makes 104
    ]
    
    // MARK: - Name Mapping Functions
    
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
    
    // MARK: - COE Mapping Functions
    
    /// Get the COE values for a manufacturer
    /// - Parameter code: The shorthand manufacturer code (e.g., "EF", "TAG")
    /// - Returns: An array of COE values, or nil if the code is not found
    static func coeValues(for code: String) -> [Int]? {
        return manufacturerCOEs[code]
    }
    
    /// Get the primary (first) COE value for a manufacturer
    /// - Parameter code: The shorthand manufacturer code
    /// - Returns: The primary COE value, or nil if the code is not found
    static func primaryCOE(for code: String) -> Int? {
        return manufacturerCOEs[code]?.first
    }
    
    /// Check if a manufacturer supports a specific COE value
    /// - Parameters:
    ///   - code: The shorthand manufacturer code
    ///   - coe: The COE value to check
    /// - Returns: True if the manufacturer supports this COE, false otherwise
    static func supports(code: String, coe: Int) -> Bool {
        return manufacturerCOEs[code]?.contains(coe) ?? false
    }
    
    /// Get all manufacturers that support a specific COE value
    /// - Parameter coe: The COE value to search for
    /// - Returns: An array of manufacturer codes that support this COE
    static func manufacturers(for coe: Int) -> [String] {
        return manufacturerCOEs.compactMap { (code, coes) in
            coes.contains(coe) ? code : nil
        }.sorted()
    }
    
    /// Get all unique COE values across all manufacturers
    /// - Returns: A sorted array of all COE values
    static var allCOEValues: [Int] {
        let allCOEs = manufacturerCOEs.values.flatMap { $0 }
        return Array(Set(allCOEs)).sorted()
    }
    
    // MARK: - Color Mapping Functions
    
    /// Get the display color for a manufacturer (supports both codes and full names)
    /// - Parameter manufacturer: The manufacturer code (e.g., "EF") or full name (e.g., "Effetre")
    /// - Returns: A SwiftUI Color for the manufacturer
    static func colorForManufacturer(_ manufacturer: String?) -> Color {
        guard let manufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .secondary
        }
        
        // Convert to lowercase for comparison
        let cleanManufacturer = manufacturer.lowercased()
        
        // First try to get full name from code if it's a code
        let fullName = fullName(for: manufacturer)?.lowercased() ?? cleanManufacturer
        
        // Map colors based on full manufacturer names
        switch fullName {
        case "glass alchemy", "GA":
            return .blue
        case "vetrofond":
            return .green
        case "reichenbach":
            return .purple
        case "double helix", "DH":
            return .red
        case "northstar glassworks", "northstar", "NS":
            return .orange
        case "effetre", "moretti":
            return .mint
        case "trautmann art glass", "TAG":
            return .yellow
        case "creation is messy", "CiM":
            return .pink
        case "boro batch", "BB":
            return .cyan
        case "unknown":
            return .secondary
        default:
            // Generate a consistent color based on manufacturer name
            let hash = fullName.hash
            let colors: [Color] = [.indigo, .teal, .brown, .gray]
            return colors[abs(hash) % colors.count]
        }
    }
}

// MARK: - Usage Examples
extension GlassManufacturers {
    
    /// Example usage demonstrating how to use the manufacturer mapping, colors, and COE values
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
        
        // Get color for manufacturer (works with both codes and full names)
        let colorFromCode = GlassManufacturers.colorForManufacturer("EF")
        let colorFromName = GlassManufacturers.colorForManufacturer("Effetre")
        print("Color from code and name should be the same: \(colorFromCode == colorFromName)")
        
        // COE examples
        if let coeValues = GlassManufacturers.coeValues(for: "TAG") {
            print("TAG supports COE values: \(coeValues.map(String.init).joined(separator: ", "))")
        }
        
        if let primaryCOE = GlassManufacturers.primaryCOE(for: "BB") {
            print("BB's primary COE is: \(primaryCOE)")
        }
        
        let supportsC33 = GlassManufacturers.supports(code: "GA", coe: 33)
        print("GA supports COE 33: \(supportsC33)")
        
        let coe33Manufacturers = GlassManufacturers.manufacturers(for: 33)
        print("Manufacturers that make COE 33: \(coe33Manufacturers.joined(separator: ", "))")
        
        let allCOEs = GlassManufacturers.allCOEValues
        print("All available COE values: \(allCOEs.map(String.init).joined(separator: ", "))")
    }
}
