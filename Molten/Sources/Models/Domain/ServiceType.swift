//
//  ServiceType.swift
//  Molten
//
//  Created for Location Services Feature on 11/1/25.
//

import Foundation

/// Types of services that glass art locations can offer
enum ServiceType: String, Codable, CaseIterable {
    case kilnRental = "kiln_rental"
    case torchRental = "torch_rental"
    case hotshopAccess = "hotshop_access"
    case toolRental = "tool_rental"
    case studioSpace = "studio_space"
    case other = "other"

    nonisolated var displayName: String {
        switch self {
        case .kilnRental:
            return "Kiln Rental"
        case .torchRental:
            return "Torch Rental"
        case .hotshopAccess:
            return "Hot Shop Access"
        case .toolRental:
            return "Tool Rental"
        case .studioSpace:
            return "Studio Space"
        case .other:
            return "Other Services"
        }
    }

    nonisolated var icon: String {
        switch self {
        case .kilnRental:
            return "fireplace.fill"
        case .torchRental:
            return "flame.fill"
        case .hotshopAccess:
            return "building.2.fill"
        case .toolRental:
            return "wrench.and.screwdriver.fill"
        case .studioSpace:
            return "square.split.2x2.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}
