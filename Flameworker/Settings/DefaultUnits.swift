//
//  DefaultUnits.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

enum DefaultUnits: String, CaseIterable {
    case shorts = "Shorts"
    case rods = "Rods"
    case pounds = "Pounds"
    case kilograms = "Kilograms"
    
    var displayName: String {
        switch self {
        case .shorts:
            return "Shorts"
        case .rods:
            return "Rods"
        case .pounds:
            return "Pounds"
        case .kilograms:
            return "Kilograms"
        }
    }
    
    var symbol: String {
        switch self {
        case .shorts:
            return "sh"
        case .rods:
            return "rd"
        case .pounds:
            return "lbs"
        case .kilograms:
            return "kg"
        }
    }
    
    var systemImage: String {
        switch self {
        case .shorts:
            return "ruler"
        case .rods:
            return "ruler.fill"
        case .pounds:
            return "scalemass"
        case .kilograms:
            return "scalemass.fill"
        }
    }
}