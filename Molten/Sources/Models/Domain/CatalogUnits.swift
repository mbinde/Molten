//
//  CatalogUnits.swift
//  Flameworker
//
//  Created by Melissa Binde on 10/13/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Foundation

/// Enumeration representing the units for inventory items
enum CatalogUnits: Int16, CaseIterable, Identifiable, Codable {
    case ounces = 0  // Renamed from pounds
    case grams = 1   // Renamed from kilograms, keeps same raw value for backward compatibility
    case shorts = 2
    case rods = 3

    var id: Int16 { rawValue }

    /// Display name for the unit (using standard abbreviations)
    var displayName: String {
        switch self {
        case .ounces:
            return "oz"  // Standard abbreviation for ounces
        case .grams:
            return "g"  // Standard abbreviation for grams
        case .shorts:
            return "shorts"
        case .rods:
            return "rods"
        }
    }

    /// Full name for the unit
    var fullName: String {
        switch self {
        case .ounces:
            return "Ounces"
        case .grams:
            return "Grams"
        case .shorts:
            return "Shorts"
        case .rods:
            return "Rods"
        }
    }

    /// Initialize from Int16 value with fallback to grams
    init(from rawValue: Int16) {
        self = CatalogUnits(rawValue: rawValue) ?? .grams
    }

    /// Custom decoder with fallback to grams for invalid values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int16.self)
        self = CatalogUnits(rawValue: rawValue) ?? .grams
    }

    /// Check if this is a weight unit (for conversion purposes)
    var isWeightUnit: Bool {
        switch self {
        case .ounces, .grams:
            return true
        case .shorts, .rods:
            return false
        }
    }
}

