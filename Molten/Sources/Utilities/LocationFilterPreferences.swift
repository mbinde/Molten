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
    }
}
