//
//  CompleteInventoryItemModel.swift
//  Molten
//
//  Core domain model aggregating catalog items, inventory, and tags
//  Split into focused files to maintain <200 LOC per file
//

import Foundation

// MARK: - Complete Inventory Item Domain Model

/// Complete inventory item aggregating catalog item, inventory records, and tags
///
/// Architecture:
/// - Core struct (this file): Properties, initializers, protocol conformance
/// - +Aggregations: Totals, groupings, computed aggregates
/// - +Queries: Filtering, sorting, business logic queries
struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable, Sendable {
    let catalogItem: UnifiedCatalogItem
    let inventory: [InventoryModel]
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags
    let allTags: [String]  // Pre-computed combined tags for performance

    nonisolated var id: String { catalogItem.stable_id }

    // MARK: - Initializers

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

    // MARK: - Backward Compatibility

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

    // MARK: - Protocol Conformance

    nonisolated static func == (lhs: CompleteInventoryItemModel, rhs: CompleteInventoryItemModel) -> Bool {
        return lhs.catalogItem.stable_id == rhs.catalogItem.stable_id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(catalogItem.stable_id)
    }
}
