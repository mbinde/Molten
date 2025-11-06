//
//  LocationFilterPreferences.swift
//  Molten
//
//  Created for Locations filter persistence on 11/1/25.
//

import Foundation

/// Manages persistence of location filter preferences
struct LocationFilterPreferences {
    private static let filterKey = "molten.locations.selectedTypes"
    private static let techniqueKey = "molten.locations.selectedTechnique"

    /// Get the user's saved location type filters
    /// - Returns: Set of selected LocationTypes, or all types if never set
    static func getSelectedTypes() -> Set<LocationType> {
        guard let savedData = UserDefaults.standard.data(forKey: filterKey),
              let decoded = try? JSONDecoder().decode(Set<LocationType>.self, from: savedData) else {
            // Default: show all types on first launch
            return Set(LocationType.allCases)
        }
        return decoded
    }

    /// Save the user's location type filter selection
    /// - Parameter types: Set of LocationTypes to show
    static func saveSelectedTypes(_ types: Set<LocationType>) {
        if let encoded = try? JSONEncoder().encode(types) {
            UserDefaults.standard.set(encoded, forKey: filterKey)
        }
    }

    /// Reset to default (all types visible)
    static func reset() {
        UserDefaults.standard.removeObject(forKey: filterKey)
        UserDefaults.standard.removeObject(forKey: techniqueKey)
    }

    /// Get the user's saved technique filter
    /// - Returns: Selected TechniqueType, or nil if showing all techniques
    static func getSelectedTechnique() -> TechniqueType? {
        guard let savedString = UserDefaults.standard.string(forKey: techniqueKey),
              let technique = TechniqueType(rawValue: savedString) else {
            return nil  // Default: show all techniques
        }
        return technique
    }

    /// Save the user's technique filter selection
    /// - Parameter technique: TechniqueType to filter by, or nil to show all
    static func saveSelectedTechnique(_ technique: TechniqueType?) {
        if let technique = technique {
            UserDefaults.standard.set(technique.rawValue, forKey: techniqueKey)
        } else {
            UserDefaults.standard.removeObject(forKey: techniqueKey)
        }
    }
}
