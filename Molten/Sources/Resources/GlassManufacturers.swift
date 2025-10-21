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
        "BB": "Boro Batch",
        "BE": "Bullseye Glass",
        "CHB": "Chinese Boro",
        "CiM": "Creation is Messy",
        "DH": "Double Helix",
        "DS": "Delphi Superior",
        "EF": "Effetre",
        "GA": "Glass Alchemy",
        "GAF": "Gaffer",
        "GRE": "Greasy Glass",
        "KUG": "Kugler",
        "MA": "Molten Aura Labs",
        "MOM": "Momka Glass",
        "NS": "Northstar Glassworks",
        "OC": "Oceanside Glass",
        "OR": "Origin Glass",
        "PAR": "Parramore Glass",
        "PDX": "PDX Tubing Co",
        "RE": "Reichenbach",
        "TAG": "Trautmann Art Glass",
        "UST": "UST Glass",
        "VF": "Vetrofond",
        "WM": "Wissmach Glass",
        "Y96": "Youghiogheny Glass"
    ]
    
    nonisolated static let manufacturerImages: [String: String] = [
        "EF": "effetre",
        "DH": "dh",
        "BB": "bb",
        "CHB": "chb",
        "CiM": "cim",
        "DS": "ds",
        "GA": "ga",
        "GAF": "gaf",
        "RE": "re",
        "TAG": "tag",
        "VF": "vf",
        "NS": "ns",
        "BE": "be",
        "KUG": "kug",
        "MA": "ma",
        "OR": "or",
        "MOM": "mom",
        "GRE": "gre",
        "OC": "oc",
        "PAR": "par",
        "PDX": "pdx",
        "UST": "ust",
        "WM": "wm",
        "Y96": "y96"
    ]

    /// Tracks whether we have permission to use product-specific images from each manufacturer
    /// If false, we must always use the default manufacturer image instead
    nonisolated static let productImagePermissions: [String: Bool] = [
        "BB": true,           // Boro Batch - permission granted
        "BE": true,           // Bullseye Glass - permission granted
        "CHB": true,          // Chinese Boro - permission TBD
        "CiM": false,         // Creation is Messy - NO permission
        "DH": true,           // Double Helix - permission granted
        "DS": false,          // Delphi Superior - NO product images (bot-protected site)
        "EF": true,           // Effetre - permission granted
        "GA": true,           // Glass Alchemy - permission granted
        "GAF": false,         // Gaffer - NO product images (bot-protected site)
        "GRE": true,          // Greasy Glass - permission granted
        "KUG": true,          // Kugler - permission granted
        "MA": true,           // Molten Aura Labs - permission granted
        "MOM": true,          // Momka Glass - permission granted
        "MOR": true,          // Moretti (same as Effetre) - permission granted
        "NS": true,           // Northstar Glassworks - permission granted
        "OC": true,           // Oceanside Glass - permission granted
        "OR": true,           // Origin Glass - permission granted
        "PAR": true,          // Parramore Glass - permission TBD
        "PDX": true,          // PDX Tubing Co - permission TBD
        "RE": true,           // Reichenbach - permission granted
        "TAG": true,          // Trautmann Art Glass - permission granted
        "UST": true,          // UST Glass - permission TBD
        "VF": true,           // Vetrofond - permission granted
        "WM": true,           // Wissmach Glass - permission granted
        "Y96": true           // Youghiogheny Glass - permission TBD
    ]

    /// Get the default manufacturer image name for a manufacturer code
    /// - Parameter code: The manufacturer code (e.g., "EF", "DH")
    /// - Returns: The image filename without extension, or nil if no default image exists
    nonisolated static func defaultImageName(for code: String?) -> String? {
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
    nonisolated static func hasProductImagePermission(for code: String?) -> Bool {
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
        "CHB": [33],          // Chinese Boro makes 33
        "CiM": [33],          // Creation is Messy makes 33
        "GA": [33],           // Glass Alchemy makes 33
        "GRE": [33],          // Greasy Glass makes 33
        "MA": [33],           // Molten Aura Labs makes 33
        "MOM": [33],          // Momka Glass makes 33
        "NS": [33],           // Northstar Glassworks makes 33
        "OR": [33],           // Origin Glass makes 33
        "PAR": [33],          // Parramore Glass makes 33
        "PDX": [33],          // PDX Tubing Co makes 33
        "TAG": [33, 104],     // Trautmann Art Glass makes both 33 and 104
        "UST": [33],          // UST Glass makes 33
        "BE": [90],           // Bullseye Glass makes 90
        "DS": [90],           // Delphi Superior makes 90
        "GAF": [96],          // Gaffer makes 96
        "OC": [96],           // Oceanside Glass makes 96
        "WM": [96],           // Wissmach Glass makes 96
        "Y96": [96],          // Youghiogheny Glass makes 96
        "DH": [104],          // Double Helix makes 104
        "EF": [104],          // Effetre makes 104
        "KUG": [104],         // Kugler makes 104
        "RE": [104],          // Reichenbach makes 104
        "VF": [104]           // Vetrofond makes 104
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
        case "bullseye glass", "bullseye", "be":
            return .indigo
        case "chinese boro", "chb":
            return Color(red: 0.6, green: 0.9, blue: 0.4)  // Lime/light green
        case "delphi superior", "ds":
            return Color(red: 0.4, green: 0.7, blue: 0.9)  // Light blue
        case "gaffer", "gaf":
            return Color(red: 0.5, green: 0.3, blue: 0.8)  // Deep purple/violet
        case "kugler", "kug":
            return .brown
        case "greasy glass", "gre":
            return .teal
        case "molten aura labs", "molten aura", "ma":
            return Color(red: 0.5, green: 0.9, blue: 0.8)  // Aqua/light teal
        case "momka glass", "mom":
            return Color(red: 0.9, green: 0.4, blue: 0.7)  // Pink-purple
        case "oceanside glass", "oc":
            return Color(red: 0.0, green: 0.6, blue: 0.8)  // Ocean blue
        case "origin glass", "or":
            return .gray
        case "parramore glass", "par":
            return Color(red: 0.7, green: 0.3, blue: 0.9)  // Purple/lavender
        case "pdx tubing co", "pdx":
            return Color(red: 0.3, green: 0.8, blue: 0.7)  // Turquoise
        case "ust glass", "ust":
            return Color(red: 0.9, green: 0.5, blue: 0.3)  // Salmon/coral
        case "wissmach glass", "wm":
            return Color(red: 0.6, green: 0.4, blue: 0.8)  // Purple
        case "youghiogheny glass", "y96":
            return Color(red: 0.8, green: 0.6, blue: 0.2)  // Golden/amber
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
