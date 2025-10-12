//
//  COEGlassType.swift
//  Flameworker
//
//  COE Glass Type and Preference Management
//  Created by TDD on 10/5/25.
//

import Foundation

/// Represents the different COE (Coefficient of Expansion) glass types supported
enum COEGlassType: Int, CaseIterable, Hashable {
    case coe33 = 33
    case coe90 = 90
    case coe96 = 96
    case coe104 = 104
    
    /// Display name for UI purposes
    var displayName: String {
        return "COE \(rawValue)"
    }
    
    /// Initialize from Int value with fallback to coe96 (most common)
    static func safeInit(from rawValue: Int) -> COEGlassType {
        return COEGlassType(rawValue: rawValue) ?? .coe96
    }
}

/// Manages user preferences for COE glass filtering
class COEGlassPreference {
    
    /// Storage key for UserDefaults
    static let storageKey = "selectedCoeGlassFilter"
    
    /// Storage key for multi-selection (new)
    static let multiSelectionStorageKey = "selectedCoeGlassTypes"
    
    /// UserDefaults instance (can be overridden for testing)
    private static var userDefaults: UserDefaults = .standard
    
    /// Current COE glass filter preference (legacy single selection)
    static var current: COEGlassType? {
        let rawValue = userDefaults.integer(forKey: storageKey)
        if rawValue == 0 {
            return nil // Default: no filter
        }
        return COEGlassType(rawValue: rawValue)
    }
    
    /// Selected COE types (multi-selection)
    static var selectedCOETypes: Set<COEGlassType> {
        print("DEBUG: Checking for data at key: \(multiSelectionStorageKey)")
        
        // Check if we have explicit data stored (including empty sets)
        if let data = userDefaults.data(forKey: multiSelectionStorageKey) {
            print("DEBUG: Found data, decoding...")
            do {
                let rawValues = try JSONDecoder().decode(Set<Int>.self, from: data)
                print("DEBUG: Decoded raw values: \(rawValues)")
                let coeTypes = rawValues.compactMap { COEGlassType(rawValue: $0) }
                let result = Set(coeTypes)
                print("DEBUG: Returning stored data: \(result)")
                return result
            } catch {
                // If decoding fails, fall through to default
                print("DEBUG: Failed to decode COE types: \(error)")
            }
        } else {
            print("DEBUG: No data found at key, using default")
        }
        
        // Default: all COE types selected (only when no explicit data exists)
        let defaultResult = Set(COEGlassType.allCases)
        print("DEBUG: Returning default: \(defaultResult)")
        return defaultResult
    }
    
    /// Set the COE filter preference (legacy single selection)
    static func setCOEFilter(_ coeType: COEGlassType?) {
        if let coeType = coeType {
            userDefaults.set(coeType.rawValue, forKey: storageKey)
        } else {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
    
    /// Add a COE type to the multi-selection
    static func addCOEType(_ coeType: COEGlassType) {
        var current = selectedCOETypes
        current.insert(coeType)
        saveSelectedCOETypes(current)
    }
    
    /// Remove a COE type from the multi-selection
    static func removeCOEType(_ coeType: COEGlassType) {
        var current = selectedCOETypes
        current.remove(coeType)
        saveSelectedCOETypes(current)
    }
    
    /// Set the complete multi-selection
    static func setSelectedCOETypes(_ coeTypes: Set<COEGlassType>) {
        saveSelectedCOETypes(coeTypes)
    }
    
    /// Save selected COE types to UserDefaults
    private static func saveSelectedCOETypes(_ coeTypes: Set<COEGlassType>) {
        let rawValues = Set(coeTypes.map { $0.rawValue })
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: multiSelectionStorageKey)
            userDefaults.synchronize() // Force immediate save for testing
        }
    }
    
    /// Reset to default (all COE types selected)
    static func resetToDefault() {
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.removeObject(forKey: multiSelectionStorageKey)
        userDefaults.synchronize() // Force immediate save for testing
    }
    
    /// Set UserDefaults instance (for testing)
    static func setUserDefaults(_ defaults: UserDefaults) {
        userDefaults = defaults
    }
}
