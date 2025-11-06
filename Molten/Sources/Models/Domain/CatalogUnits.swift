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
    case pounds = 0
    case kilograms = 1
    case shorts = 2
    case rods = 3
    
    var id: Int16 { rawValue }
    
    /// Display name for the unit (using standard abbreviations)
    var displayName: String {
        switch self {
        case .pounds:
            return "lbs"  // Standard abbreviation for pounds
        case .kilograms:
            return "kg"  // Standard abbreviation for kilograms
        case .shorts:
            return "shorts"
        case .rods:
            return "rods"
        }
    }

    /// Full name for the unit
    var fullName: String {
        switch self {
        case .pounds:
            return "Pounds"
        case .kilograms:
            return "Kilograms"
        case .shorts:
            return "Shorts"
        case .rods:
            return "Rods"
        }
    }

    /// Initialize from Int16 value with fallback to pounds
    init(from rawValue: Int16) {
        self = CatalogUnits(rawValue: rawValue) ?? .pounds
    }

    /// Custom decoder with fallback to pounds for invalid values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int16.self)
        self = CatalogUnits(rawValue: rawValue) ?? .pounds
    }
    
    /// Check if this is a weight unit (for conversion purposes)
    var isWeightUnit: Bool {
        switch self {
        case .pounds, .kilograms:
            return true
        case .shorts, .rods:
            return false
        }
    }
}

