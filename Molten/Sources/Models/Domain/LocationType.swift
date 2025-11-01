//
//  LocationType.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import SwiftUI

/// Enum representing different types of glass art locations
enum LocationType: String, Codable, CaseIterable, Identifiable {
    case store
    case classLocation = "class"
    case workshop

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .store:
            return "Stores"
        case .classLocation:
            return "Classes"
        case .workshop:
            return "Workshops"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .store:
            return "storefront"
        case .classLocation:
            return "graduationcap"
        case .workshop:
            return "hammer"
        }
    }

    /// Icon for the type
    var icon: Image {
        Image(systemName: iconName)
    }

    /// Short singular name (for detail views)
    var singularName: String {
        switch self {
        case .store:
            return "Store"
        case .classLocation:
            return "Class"
        case .workshop:
            return "Workshop"
        }
    }
}
