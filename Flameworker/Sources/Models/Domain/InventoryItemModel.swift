//
//  InventoryItemModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Model representing consolidated inventory items grouped by catalog code
struct ConsolidatedInventoryModel: Identifiable, Equatable, Hashable {
    let id: String
    let catalogCode: String
    let totalInventoryCount: Double
    let totalBuyCount: Double
    let totalSellCount: Double
    let items: [InventoryItemModel]
    
    init(catalogCode: String, items: [InventoryItemModel]) {
        self.id = catalogCode
        self.catalogCode = catalogCode
        self.items = items
        
        // Calculate totals by type using Double
        self.totalInventoryCount = items.filter { $0.type == .inventory }.reduce(0.0) { $0 + $1.quantity }
        self.totalBuyCount = items.filter { $0.type == .buy }.reduce(0.0) { $0 + $1.quantity }
        self.totalSellCount = items.filter { $0.type == .sell }.reduce(0.0) { $0 + $1.quantity }
    }
    
    /// Display name for the consolidated item
    var displayName: String {
        return catalogCode
    }
}

/// Simple data model for inventory items, following repository pattern
struct InventoryItemModel: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let catalogCode: String
    let quantity: Double
    let type: InventoryItemType
    let notes: String?
    let location: String?
    let dateAdded: Date
    
    init(
        id: String = UUID().uuidString,
        catalogCode: String,
        quantity: Double,
        type: InventoryItemType,
        notes: String? = nil,
        location: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.catalogCode = catalogCode
        self.quantity = quantity
        self.type = type
        self.notes = notes
        self.location = location
        self.dateAdded = dateAdded
    }
}

// MARK: - Business Logic Extensions

extension InventoryItemModel {
    /// Display name combining catalog code and type
    var displayName: String {
        return "\(catalogCode) (\(type.displayName): \(quantity))"
    }
    
    /// Check if item matches search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return catalogCode.lowercased().contains(lowercaseSearch) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false)
    }
    
    /// Determine if this item has changes compared to another
    static func hasChanges(existing: InventoryItemModel, new: InventoryItemModel) -> Bool {
        return existing.catalogCode != new.catalogCode ||
               existing.quantity != new.quantity ||
               existing.type != new.type ||
               existing.notes != new.notes
    }
}