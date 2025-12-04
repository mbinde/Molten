//
//  GlassItemTypeSystem.swift
//  Flameworker
//
//  Created by Assistant on 10/17/25.
//  Defines the hierarchical type system for glass inventory items
//

import Foundation

// MARK: - Type System Structures

/// Represents a single dimension field for a glass item type
nonisolated struct DimensionField: Equatable, Hashable {
    let name: String
    let displayName: String
    let unit: String
    let isRequired: Bool
    let placeholder: String

    init(name: String, displayName: String, unit: String, isRequired: Bool = false, placeholder: String? = nil) {
        self.name = name
        self.displayName = displayName
        self.unit = unit
        self.isRequired = isRequired
        self.placeholder = placeholder ?? "Enter \(displayName.lowercased())"
    }
}

/// Represents a complete glass item type with its subtypes and dimensions
nonisolated struct GlassItemType: Equatable, Hashable {
    let name: String
    let displayName: String
    let subtypes: [String]
    let subsubtypes: [String: [String]] // Map subtype to its subsubtypes
    let dimensionFields: [DimensionField]

    /// Get subsubtypes for a given subtype
    func getSubsubtypes(for subtype: String) -> [String] {
        return subsubtypes[subtype] ?? []
    }

    /// Check if this type has any subtypes defined
    var hasSubtypes: Bool {
        return !subtypes.isEmpty
    }

    /// Check if this type has any dimension fields
    var hasDimensions: Bool {
        return !dimensionFields.isEmpty
    }
}

// MARK: - Glass Item Type System

/// Central registry for all glass item types and their hierarchies
nonisolated struct GlassItemTypeSystem {

    // MARK: - Type Definitions

    static let rod = GlassItemType(
        name: "rod",
        displayName: "Rods",
        subtypes: ["standard", "cane", "pull"],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: false, placeholder: "5-6mm typical"),
            DimensionField(name: "length", displayName: "Length", unit: "cm", isRequired: false)
        ]
    )

    static let bigRod = GlassItemType(
        name: "big-rod",
        displayName: "Bars",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "length", displayName: "Length", unit: "cm", isRequired: false)
        ]
    )

    static let stringer = GlassItemType(
        name: "stringer",
        displayName: "Stringers",
        subtypes: ["1mm", "2mm", "Hand-pulled"],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "length", displayName: "Length", unit: "cm", isRequired: false)
        ]
    )

    static let sheet = GlassItemType(
        name: "sheet",
        displayName: "Sheets",
        subtypes: ["full", "half", "12x12", "10x10", "4x4", "other"],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "thickness", displayName: "Thickness", unit: "mm", isRequired: false),
            DimensionField(name: "width", displayName: "Width", unit: "cm", isRequired: false),
            DimensionField(name: "height", displayName: "Height", unit: "cm", isRequired: false)
        ]
    )

    static let frit = GlassItemType(
        name: "frit",
        displayName: "Frit",
        subtypes: ["#25", "#38", "#70", "#82", "#100", "coarse", "medium", "fine"],
        subsubtypes: [:],
        dimensionFields: []
    )

    static let tube = GlassItemType(
        name: "tube",
        displayName: "Tubes",
        subtypes: ["thin wall", "thick wall", "standard"],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "outer_diameter", displayName: "Outer Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "inner_diameter", displayName: "Inner Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "length", displayName: "Length", unit: "cm", isRequired: false)
        ]
    )

    static let powder = GlassItemType(
        name: "powder",
        displayName: "Powder",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: []
    )

    static let scrap = GlassItemType(
        name: "scrap",
        displayName: "Scrap",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: []
    )

    static let murriniCane = GlassItemType(
        name: "murrini-cane",
        displayName: "Murrini Canes",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "length", displayName: "Length", unit: "cm", isRequired: false)
        ]
    )

    static let murriniSlice = GlassItemType(
        name: "murrini-slice",
        displayName: "Murrini Slices",
        subtypes: [],
        subsubtypes: [:],
        dimensionFields: [
            DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: false),
            DimensionField(name: "thickness", displayName: "Thickness", unit: "mm", isRequired: false)
        ]
    )

    // MARK: - Type Registry

    /// All available glass item types (backend storage types)
    /// Note: Enamel is NOT a glass type - it's a coating (see CoatingItemTypeSystem)
    nonisolated static let allTypes: [GlassItemType] = [
        rod,
        bigRod,
        stringer,
        sheet,
        frit,
        tube,
        powder,
        scrap,
        murriniCane,
        murriniSlice
    ]

    /// Map of type name to GlassItemType for quick lookup
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

    /// Get subtypes for a given type
    static func getSubtypes(for typeName: String) -> [String] {
        return getType(named: typeName)?.subtypes ?? []
    }

    /// Get subsubtypes for a given type and subtype
    static func getSubsubtypes(for typeName: String, subtype: String) -> [String] {
        return getType(named: typeName)?.getSubsubtypes(for: subtype) ?? []
    }

    /// Get dimension fields for a given type
    static func getDimensionFields(for typeName: String) -> [DimensionField] {
        return getType(named: typeName)?.dimensionFields ?? []
    }

    /// Check if a type has subtypes
    static func hasSubtypes(_ typeName: String) -> Bool {
        return getType(named: typeName)?.hasSubtypes ?? false
    }

    /// Check if a type has dimensions
    static func hasDimensions(_ typeName: String) -> Bool {
        return getType(named: typeName)?.hasDimensions ?? false
    }

    // MARK: - Validation

    /// Validate that a type name is valid
    static func isValidType(_ typeName: String) -> Bool {
        return typesByName[typeName.lowercased()] != nil
    }

    /// Validate that a subtype is valid for a given type
    static func isValidSubtype(_ subtype: String, for typeName: String) -> Bool {
        guard let type = getType(named: typeName) else { return false }
        return type.subtypes.contains(subtype.lowercased())
    }

    /// Validate that a subsubtype is valid for a given type and subtype
    static func isValidSubsubtype(_ subsubtype: String, for typeName: String, subtype: String) -> Bool {
        guard let type = getType(named: typeName) else { return false }
        return type.getSubsubtypes(for: subtype).contains(subsubtype.lowercased())
    }

    /// Validate dimensions for a given type
    static func validateDimensions(_ dimensions: [String: Double], for typeName: String) -> [String] {
        guard let type = getType(named: typeName) else {
            return ["Invalid type: \(typeName)"]
        }

        var errors: [String] = []

        // Check for required dimensions
        for field in type.dimensionFields where field.isRequired {
            if dimensions[field.name] == nil {
                errors.append("Required dimension '\(field.displayName)' is missing")
            }
        }

        // Check for invalid dimension values
        for (key, value) in dimensions {
            if value < 0 {
                errors.append("Dimension '\(key)' cannot be negative")
            }
        }

        return errors
    }

    // MARK: - Display Helpers

    /// Format dimension value for display
    nonisolated static func formatDimension(value: Double, field: DimensionField) -> String {
        let formattedValue: String
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formattedValue = String(format: "%.0f", value)
        } else {
            formattedValue = String(format: "%.1f", value)
        }
        return "\(formattedValue) \(field.unit)"
    }

    /// Format dimensions dictionary for display
    static func formatDimensions(_ dimensions: [String: Double], for typeName: String) -> String {
        guard let type = getType(named: typeName) else { return "" }

        let formattedPairs = type.dimensionFields.compactMap { field -> String? in
            guard let value = dimensions[field.name] else { return nil }
            return "\(field.displayName): \(formatDimension(value: value, field: field))"
        }

        return formattedPairs.joined(separator: ", ")
    }

    /// Get a short display string for inventory type info
    nonisolated static func shortDescription(type: String, subtype: String?, dimensions: [String: Double]?) -> String {
        var parts: [String] = [type.capitalized]

        if let subtype = subtype, !subtype.isEmpty {
            parts.append("(\(subtype.capitalized))")
        }

        if let dims = dimensions, !dims.isEmpty, let typeInfo = getType(named: type) {
            // Show first dimension only for compact display
            if let firstField = typeInfo.dimensionFields.first,
               let value = dims[firstField.name] {
                parts.append(formatDimension(value: value, field: firstField))
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Display Name Methods

    /// Get type display name (using terminology settings for customization)
    /// - Parameter typeName: Backend type name (e.g., "rod", "big-rod")
    /// - Returns: User-facing display name
    @MainActor static func displayName(for typeName: String) -> String {
        // For rod types, use terminology settings (allows user customization)
        if typeName.lowercased() == "rod" || typeName.lowercased() == "big-rod" {
            return GlassTerminologySettings.shared.displayName(for: typeName.lowercased())
        }

        // For other types, use the default display name
        return getType(named: typeName)?.displayName ?? typeName.capitalized
    }

    /// Get backend type name from a user-facing display name
    /// - Parameter displayName: The display name shown to the user
    /// - Returns: Backend storage type name, or nil if not found
    @MainActor static func backendTypeName(from displayName: String) -> String? {
        // Check if this is a rod type that might use custom terminology
        if let converted = GlassTerminologySettings.shared.backendType(from: displayName) {
            if isValidType(converted) {
                return converted
            }
        }

        // Otherwise, try to find by matching display name
        return allTypes.first(where: { $0.displayName.lowercased() == displayName.lowercased() })?.name
    }
}
