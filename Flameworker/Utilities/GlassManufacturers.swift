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
        "NS": "Northstar Glassworks"
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
        case "effetre", "moretti":
            return .blue
        case "vetrofond":
            return .green
        case "reichenbach":
            return .purple
        case "double helix":
            return .orange
        case "northstar glassworks", "northstar":
            return .red
        case "glass alchemy":
            return .mint
        case "trautmann art glass":
            return .yellow
        case "creation is messy":
            return .pink
        case "boro batch":
            return .cyan
        case "zimmermann":
            return .yellow
        case "kugler":
            return .pink
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
    
    /// Example usage demonstrating how to use the manufacturer mapping and colors
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
    }
}