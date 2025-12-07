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
    let storageLocations: [StorageLocationModel]  // Where inventory is stored (new architecture)
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags
    let allTags: [String]  // Pre-computed combined tags for performance
    let rating: AggregatedRatingModel?  // Optional rating data (loaded on-demand for sorting)

    nonisolated var id: String { catalogItem.stable_id }

    // MARK: - Initializers

    /// Initialize with automatic allTags computation
    nonisolated init(catalogItem: UnifiedCatalogItem, inventory: [InventoryModel], storageLocations: [StorageLocationModel] = [], tags: [String], userTags: [String], rating: AggregatedRatingModel? = nil) {
        self.catalogItem = catalogItem
        self.inventory = inventory
        self.storageLocations = storageLocations
        self.tags = tags
        self.userTags = userTags
        self.rating = rating
        // Pre-compute allTags for performance (avoid repeated computation in views)
        self.allTags = Array(Set(tags + userTags)).sorted()
    }

    /// Convenience initializer from GlassItemModel (for backward compatibility)
    nonisolated init(glassItem: GlassItemModel, inventory: [InventoryModel], storageLocations: [StorageLocationModel] = [], tags: [String], userTags: [String], rating: AggregatedRatingModel? = nil) {
        self.init(catalogItem: UnifiedCatalogItem(glassItem: glassItem), inventory: inventory, storageLocations: storageLocations, tags: tags, userTags: userTags, rating: rating)
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
            image_path: catalogItem.image_path,
            image_thumb_path: catalogItem.image_thumb_path,
            dominant_colors: catalogItem.dominant_colors
        )
    }

    // MARK: - Protocol Conformance

    nonisolated static func == (lhs: CompleteInventoryItemModel, rhs: CompleteInventoryItemModel) -> Bool {
        return lhs.catalogItem.stable_id == rhs.catalogItem.stable_id &&
               lhs.inventory == rhs.inventory &&
               lhs.storageLocations == rhs.storageLocations &&
               lhs.tags == rhs.tags &&
               lhs.userTags == rhs.userTags &&
               lhs.rating?.averageRating == rhs.rating?.averageRating &&
               lhs.rating?.totalRatings == rhs.rating?.totalRatings
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(catalogItem.stable_id)
        hasher.combine(inventory)
        hasher.combine(storageLocations)
        hasher.combine(rating?.averageRating)
        hasher.combine(rating?.totalRatings)
    }
}
