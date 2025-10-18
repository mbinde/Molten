//
//  GlassManufacturers.swift
//  Flameworker
//
//  Combined and Enhanced Version - Utilities
//  Created by Assistant on 10/01/25.
//

import Foundation
import SwiftUI

/// A comprehensive structure that manages glass manufacturer information including name mappings, COE values, and UI colors
/// This is the authoritative source for all manufacturer-related functionality in the app
struct GlassManufacturers {
    
    // MARK: - Static Data Mappings
    
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
        "KUG": "Kugler",
        "MOR": "Moretti"
    ]
    
    static let manufacturerImages: [String: String] = [
        "EF": "effetre",
        "DH": "dh",
        "BB": "bb",
        "CiM": "cim",
        "GA": "ga",
        "RE": "re",
        "TAG": "tag",
        "VF": "vf",
        "NS": "ns",
        "BE": "be",
        "KUG": "kug"
    ]

    /// Tracks whether we have permission to use product-specific images from each manufacturer
    /// If false, we must always use the default manufacturer image instead
    static let productImagePermissions: [String: Bool] = [
        "EF": true,           // Effetre - permission granted
        "DH": true,           // Double Helix - permission granted
        "BB": true,           // Boro Batch - permission granted
        "CiM": false,         // Creation is Messy - NO permission
        "GA": true,           // Glass Alchemy - permission granted
        "RE": true,           // Reichenbach - permission granted
        "TAG": true,          // Trautmann Art Glass - permission granted
        "VF": true,           // Vetrofond - permission granted
        "NS": true,           // Northstar Glassworks - permission granted
        "BE": true,           // Bullseye - permission granted
        "KUG": true,          // Kugler - permission granted
        "MOR": true           // Moretti - permission granted
    ]

    /// Get the default manufacturer image name for a manufacturer code
    /// - Parameter code: The manufacturer code (e.g., "EF", "DH")
    /// - Returns: The image filename without extension, or nil if no default image exists
    static func defaultImageName(for code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        // Try exact match first
        if let imageName = manufacturerImages[code] {
            return imageName
        }

        // Try case-insensitive match
        let result = manufacturerImages.first { $0.key.caseInsensitiveCompare(code) == .orderedSame }?.value
        return result
    }

    /// Check if we have permission to use product-specific images for a manufacturer
    /// - Parameter code: The manufacturer code (e.g., "EF", "CiM")
    /// - Returns: True if we can use product-specific images, false if we must use default manufacturer image
    static func hasProductImagePermission(for code: String?) -> Bool {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        // Try exact match first
        if let permission = productImagePermissions[code] {
            return permission
        }

        // Try case-insensitive match
        if let permission = productImagePermissions.first(where: { $0.key.caseInsensitiveCompare(code) == .orderedSame })?.value {
            return permission
        }

        // Default to false (no permission) for unknown manufacturers
        return false
    }
    
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
        "KUG": [104],         // Kugler makes 104
        "MOR": [104]          // Moretti makes 104
    ]
    
    // MARK: - Name Mapping Functions
    
    /// Get the full manufacturer name from a shorthand code (case-insensitive)
    /// - Parameter code: The shorthand manufacturer code (e.g., "EF", "ef", "Ef")
    /// - Returns: The full manufacturer name, or nil if the code is not found
    static func fullName(for code: String) -> String? {
        // Direct lookup with case-insensitive matching
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try exact match first
        if let name = manufacturers[cleanCode] {
            return name
        }

        // Try case-insensitive match
        return manufacturers.first { $0.key.caseInsensitiveCompare(cleanCode) == .orderedSame }?.value
    }
    
    /// Get all available manufacturer codes
    /// - Returns: An array of all shorthand codes, sorted alphabetically
    static var allCodes: [String] {
        return Array(manufacturers.keys).sorted()
    }
    
    /// Get all manufacturer full names
    /// - Returns: An array of all full manufacturer names, sorted alphabetically
    static var allNames: [String] {
        return Array(manufacturers.values).sorted()
    }
    
    /// Check if a manufacturer code exists
    /// - Parameter code: The shorthand code to check
    /// - Returns: True if the code exists, false otherwise
    static func isValid(code: String) -> Bool {
        return manufacturers[code] != nil
    }
    
    /// Find manufacturer code from full name (reverse lookup)
    /// - Parameter fullName: The full manufacturer name
    /// - Returns: The shorthand code, or nil if not found
    static func code(for fullName: String) -> String? {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return manufacturers.first { $0.value.caseInsensitiveCompare(cleanName) == .orderedSame }?.key
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
    /// - Returns: An array of manufacturer codes that support this COE, sorted alphabetically
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
    /// This is the authoritative color mapping function that replaces all other scattered implementations
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
        
        // Map colors based on full manufacturer names and common aliases
        switch fullName {
        case "glass alchemy", "ga":
            return .blue
        case "vetrofond", "vf":
            return .green
        case "reichenbach", "re":
            return .purple
        case "double helix", "dh":
            return .red
        case "northstar glassworks", "northstar", "ns":
            return .orange
        case "effetre", "moretti", "ef", "mor":
            return .mint
        case "trautmann art glass", "tag":
            return .yellow
        case "creation is messy", "cim":
            return .pink
        case "boro batch", "bb":
            return .cyan
        case "bullseye", "be":
            return .indigo
        case "kugler", "kug":
            return .brown
        case "unknown", "":
            return .secondary
        default:
            // Generate a consistent color based on manufacturer name
            let hash = fullName.hash
            let colors: [Color] = [.gray, .primary, .accentColor]
            return colors[abs(hash) % colors.count]
        }
    }
    
    // MARK: - Utility Functions
    
    /// Normalize manufacturer name/code for consistent lookup
    /// - Parameter input: Raw manufacturer string (could be code, full name, or mixed case)
    /// - Returns: A tuple of (code, fullName) if found, or nil if not recognized
    static func normalize(_ input: String?) -> (code: String, fullName: String)? {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else {
            return nil
        }
        
        // Try as code first
        if let fullName = fullName(for: input) {
            return (code: input, fullName: fullName)
        }
        
        // Try as full name
        if let code = code(for: input) {
            return (code: code, fullName: input)
        }
        
        // Try case-insensitive matching
        let lowercaseInput = input.lowercased()
        
        // Check codes case-insensitively
        for (code, name) in manufacturers {
            if code.lowercased() == lowercaseInput {
                return (code: code, fullName: name)
            }
            if name.lowercased() == lowercaseInput {
                return (code: code, fullName: name)
            }
        }
        
        return nil
    }
    
    /// Get comprehensive manufacturer information
    /// - Parameter identifier: Manufacturer code or full name
    /// - Returns: A ManufacturerInfo struct with all available data
    static func info(for identifier: String?) -> ManufacturerInfo? {
        guard let normalized = normalize(identifier) else {
            return nil
        }
        
        return ManufacturerInfo(
            code: normalized.code,
            fullName: normalized.fullName,
            coeValues: coeValues(for: normalized.code) ?? [],
            primaryCOE: primaryCOE(for: normalized.code),
            color: colorForManufacturer(normalized.code)
        )
    }
    
    // MARK: - Search Functions
    
    /// Search manufacturers by partial name or code
    /// - Parameter searchTerm: Partial text to search for
    /// - Returns: Array of matching manufacturer codes
    static func search(_ searchTerm: String) -> [String] {
        let lowercaseSearch = searchTerm.lowercased()
        
        return manufacturers.compactMap { (code, name) in
            if code.lowercased().contains(lowercaseSearch) ||
               name.lowercased().contains(lowercaseSearch) {
                return code
            }
            return nil
        }.sorted()
    }
    
    /// Get manufacturers grouped by COE value
    /// - Returns: Dictionary mapping COE values to arrays of manufacturer codes
    static var manufacturersByCOE: [Int: [String]] {
        var result: [Int: [String]] = [:]
        
        for coe in allCOEValues {
            result[coe] = manufacturers(for: coe)
        }
        
        return result
    }
}

// MARK: - Supporting Types

/// Comprehensive manufacturer information structure
struct ManufacturerInfo {
    let code: String
    let fullName: String
    let coeValues: [Int]
    let primaryCOE: Int?
    let color: Color
    
    /// Check if this manufacturer supports a specific COE
    func supports(coe: Int) -> Bool {
        return coeValues.contains(coe)
    }
    
    /// Get display name with COE information
    var displayNameWithCOE: String {
        if coeValues.count == 1 {
            return "\(fullName) (COE \(coeValues[0]))"
        } else if coeValues.count > 1 {
            let coeList = coeValues.map(String.init).joined(separator: ", ")
            return "\(fullName) (COE \(coeList))"
        } else {
            return fullName
        }
    }
}

// MARK: - Usage Examples
extension GlassManufacturers {
    
    /// Example usage demonstrating how to use the manufacturer mapping, colors, and COE values
    static func examples() {
        print("=== GlassManufacturers Usage Examples ===")
        
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
        print("Color consistency check: \(colorFromCode == colorFromName)")
        
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
        
        // New functionality examples
        if let info = GlassManufacturers.info(for: "effetre") {
            print("Effetre info: \(info.displayNameWithCOE)")
        }
        
        let searchResults = GlassManufacturers.search("glass")
        print("Search for 'glass': \(searchResults.joined(separator: ", "))")
        
        print("=== End Examples ===")
    }
}
