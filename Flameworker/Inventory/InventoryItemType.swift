//
//  InventoryItemType.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation

/// Enumeration representing the type of inventory item
enum InventoryItemType: Int16, CaseIterable, Identifiable {
    case inventory = 0
    case buy = 1
    case sell = 2
    
    var id: Int16 { rawValue }
    
    /// Human-readable display name for the type
    var displayName: String {
        switch self {
        case .inventory:
            return "Inventory"
        case .buy:
            return "Buy"
        case .sell:
            return "Sell"
        }
    }
    
    /// System image name for the type
    var systemImageName: String {
        switch self {
        case .inventory:
            return "archivebox.fill"
        case .buy:
            return "cart.badge.plus"
        case .sell:
            return "cart.badge.minus"
        }
    }
    
    /// Color associated with the type
    var color: SwiftUI.Color {
        switch self {
        case .inventory:
            return .blue
        case .buy:
            return .green
        case .sell:
            return .orange
        }
    }
    
    /// Initialize from Int16 value with fallback to inventory
    init(from rawValue: Int16) {
        self = InventoryItemType(rawValue: rawValue) ?? .inventory
    }
}

// MARK: - InventoryItem Extension

extension InventoryItem {
    /// Computed property to get the type as an enum
    var itemType: InventoryItemType {
        get {
            return InventoryItemType(from: type)
        }
        set {
            type = newValue.rawValue
        }
    }
    
    /// Display string for the type
    var typeDisplayName: String {
        return itemType.displayName
    }
    
    /// System image for the type
    var typeSystemImage: String {
        return itemType.systemImageName
    }
    
    /// Color for the type
    var typeColor: SwiftUI.Color {
        return itemType.color
    }
}

import SwiftUI