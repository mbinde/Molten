//
//  InventoryUnits.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import Foundation

/// Enumeration representing the units for inventory items
enum InventoryUnits: Int16, CaseIterable, Identifiable {
    case pounds = 0
    case kilograms = 1
    case shorts = 2
    case rods = 3
    
    var id: Int16 { rawValue }
    
    /// Display name for the unit (using standard abbreviations)
    var displayName: String {
        switch self {
        case .pounds:
            return "lb"  // Standard abbreviation for pounds
        case .kilograms:
            return "kg"  // Standard abbreviation for kilograms  
        case .shorts:
            return "Shorts"
        case .rods:
            return "Rods"
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
        self = InventoryUnits(rawValue: rawValue) ?? .pounds
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