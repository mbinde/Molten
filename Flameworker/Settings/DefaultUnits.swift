//
//  DefaultUnits.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

enum DefaultUnits: String, CaseIterable {
    case pounds = "Pounds"
    case kilograms = "Kilograms"
    
    var displayName: String {
        switch self {
        case .pounds:
            return "Pounds"
        case .kilograms:
            return "Kilograms"
        }
    }
    
    var symbol: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pounds:
            return "scalemass"
        case .kilograms:
            return "scalemass.fill"
        }
    }
}