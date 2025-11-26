//
//  CoatingItemTypeSystem.swift
//  Molten
//
//  Defines the type system for coating inventory items (powder, flakes)
//

import Foundation

// MARK: - Coating Item Type System

/// Central registry for all coating item types
nonisolated struct CoatingItemTypeSystem {

    // MARK: - Type Definitions

    static let powder = GlassItemType(
        name: "powder",
        displayName: "Powder",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: []
    )

    static let flakes = GlassItemType(
        name: "flakes",
        displayName: "Flakes",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: []
    )

    // MARK: - Type Registry

    /// All available coating item types
    nonisolated static let allTypes: [GlassItemType] = [
        powder,
        flakes
    ]

    /// Map of type name to type for quick lookup
    nonisolated static let typesByName: [String: GlassItemType] = {
        Dictionary(uniqueKeysWithValues: allTypes.map { ($0.name, $0) })
    }()

    // MARK: - Lookup Methods

    /// Get type definition by name
    nonisolated static func getType(named name: String) -> GlassItemType? {
        return typesByName[name.lowercased()]
    }

    /// Get all type names (for pickers, etc.)
    static var allTypeNames: [String] {
        return allTypes.map { $0.name }
    }

    /// Get display names for all types
    static var allTypeDisplayNames: [String] {
        return allTypes.map { $0.displayName }
    }

    /// Default type for coatings
    static var defaultType: String {
        return "powder"
    }

    /// Check if a type is weight-based (all coating types are)
    static func isWeightBasedType(_ typeName: String) -> Bool {
        return true  // All coating types are weight-based
    }
}
