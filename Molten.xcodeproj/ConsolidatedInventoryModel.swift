//
//  ConsolidatedInventoryModel.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//  Model for consolidated inventory data representation
//

import Foundation

/// Represents consolidated inventory data for a single catalog item
/// Combines multiple inventory entries for the same catalog code into summary statistics
struct ConsolidatedInventoryModel: Identifiable, Equatable {
    let id = UUID().uuidString
    let catalogCode: String
    let items: [InventoryItemModel]
    
    // Computed properties for display
    var displayName: String {
        // Try to get catalog name from service if available
        // For now, use catalog code as display name
        catalogCode
    }
    
    var manufacturer: String {
        // This should be populated from catalog data
        "Unknown"
    }
    
    var totalInventoryCount: Double {
        items.filter { $0.type == .inventory }.reduce(0) { $0 + $1.quantity }
    }
    
    var totalBuyCount: Double {
        items.filter { $0.type == .buy }.reduce(0) { $0 + $1.quantity }
    }
    
    var totalSellCount: Double {
        items.filter { $0.type == .sell }.reduce(0) { $0 + $1.quantity }
    }
    
    /// Net quantity (inventory - sell)
    var netQuantity: Double {
        totalInventoryCount - totalSellCount
    }
    
    /// Whether this item has low inventory
    func hasLowQuantity(threshold: Double) -> Bool {
        totalInventoryCount < threshold
    }
    
    /// Items of a specific type
    func items(ofType type: InventoryItemType) -> [InventoryItemModel] {
        items.filter { $0.type == type }
    }
    
    // MARK: - Initializers
    
    init(catalogCode: String, items: [InventoryItemModel]) {
        self.catalogCode = catalogCode
        self.items = items
    }
    
    init(catalogCode: String, catalogName: String, manufacturer: String, items: [InventoryItemModel]) {
        self.catalogCode = catalogCode
        self.items = items
        // Note: catalogName and manufacturer are currently stored as computed properties
        // In a future version, these should be stored properties populated from catalog data
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ConsolidatedInventoryModel, rhs: ConsolidatedInventoryModel) -> Bool {
        lhs.catalogCode == rhs.catalogCode && lhs.items == rhs.items
    }
}