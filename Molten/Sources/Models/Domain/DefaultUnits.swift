//
//  DefaultUnits.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

enum DefaultUnits: String, CaseIterable {
    case ounces = "Ounces"
    case grams = "Grams"

    var displayName: String {
        switch self {
        case .ounces:
            return "Ounces"
        case .grams:
            return "Grams"
        }
    }

    var symbol: String {
        switch self {
        case .ounces:
            return "oz"
        case .grams:
            return "g"
        }
    }

    var systemImage: String {
        switch self {
        case .ounces:
            return "scalemass"
        case .grams:
            return "scalemass.fill"
        }
    }
}
