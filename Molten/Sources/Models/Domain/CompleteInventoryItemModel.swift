//
//  CompleteInventoryItemModel.swift
//  Molten
//
//  Created by Architecture Refactoring on 2025-11-08.
//  Moved from Services/Core/SharedModels.swift to Domain layer
//

import Foundation

// MARK: - Complete Inventory Item Domain Model

/// Complete inventory item aggregating catalog item, inventory records, and tags
struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable, Sendable {
    let catalogItem: UnifiedCatalogItem
    let inventory: [InventoryModel]
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags
    let allTags: [String]  // Pre-computed combined tags for performance

    nonisolated var id: String { catalogItem.stable_id }

    /// Initialize with automatic allTags computation
    nonisolated init(catalogItem: UnifiedCatalogItem, inventory: [InventoryModel], tags: [String], userTags: [String]) {
        self.catalogItem = catalogItem
        self.inventory = inventory
        self.tags = tags
        self.userTags = userTags
        // Pre-compute allTags for performance (avoid repeated computation in views)
        self.allTags = Array(Set(tags + userTags)).sorted()
    }

    /// Convenience initializer from GlassItemModel (for backward compatibility)
    nonisolated init(glassItem: GlassItemModel, inventory: [InventoryModel], tags: [String], userTags: [String]) {
        self.init(catalogItem: UnifiedCatalogItem(glassItem: glassItem), inventory: inventory, tags: tags, userTags: userTags)
    }

    /// Convenience property for accessing as GlassItemModel (for backward compatibility)
    /// ⚠️ WARNING: Only use for glass items! Check catalogItem.itemType first
    nonisolated var glassItem: GlassItemModel {
        GlassItemModel(
            stable_id: catalogItem.stable_id,
            name: catalogItem.name,
            sku: catalogItem.sku,
            manufacturer: catalogItem.manufacturer,
            mfr_notes: catalogItem.mfr_notes,
            coe: catalogItem.coe ?? 0,  // Default to 0 if nil (shouldn't happen for glass items)
            url: catalogItem.url,
            mfr_status: catalogItem.mfr_status,
            image_url: catalogItem.image_url,
            image_path: catalogItem.image_path
        )
    }

    /// Total quantity across all inventory records
    nonisolated var totalQuantity: Double {
        inventory.reduce(0.0) { $0 + $1.quantity }
    }

    /// Inventory grouped by type with total quantities
    nonisolated var inventoryByType: [String: Double] {
        Dictionary(grouping: inventory, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    /// Unique locations across all inventory records
    nonisolated var locations: [String] {
        Array(Set(inventory.compactMap { $0.location })).sorted()
    }

    /// Inventory grouped by location with total quantities
    nonisolated var inventoryByLocation: [String: Double] {
        Dictionary(grouping: inventory.filter { $0.location != nil }, by: { $0.location! })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    /// Product type as string for UI display
    nonisolated var productType: String {
        catalogItem.itemType.rawValue
    }

    /// Whether this item has any inventory (quantity > 0)
    /// Business rule: Item "has inventory" if ANY inventory record has positive quantity
    nonisolated var hasInventory: Bool {
        inventory.contains { $0.quantity > 0 }
    }

    nonisolated static func == (lhs: CompleteInventoryItemModel, rhs: CompleteInventoryItemModel) -> Bool {
        return lhs.catalogItem.stable_id == rhs.catalogItem.stable_id
    }

    // Hashable conformance for navigation
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(catalogItem.stable_id)
    }
}
