//
//  ShoppingListModels.swift
//  Molten
//
//  Created by Architecture Refactoring on 2025-11-08.
//  Moved from ShoppingListService.swift to Domain layer
//

import Foundation

// MARK: - Shopping List Domain Models

/// Detailed shopping list with complete item information
struct DetailedShoppingListModel {
    let store: String
    let items: [DetailedShoppingListItemModel]
    let totalItems: Int

    /// Business Logic: Estimated total value of shopping list
    /// Business rule: $10 per needed unit (placeholder until real pricing added)
    nonisolated var totalValue: Double {
        items.reduce(0.0) { total, item in
            total + (item.shoppingListItem.neededQuantity * 10.0)
        }
    }

    /// Items grouped by manufacturer for easier shopping
    nonisolated var itemsByManufacturer: [String: [DetailedShoppingListItemModel]] {
        Dictionary(grouping: items) { $0.catalogItem.manufacturer }
    }
}

/// Shopping list item with complete catalog item information (glass, coating, or tool)
struct DetailedShoppingListItemModel {
    let shoppingListItem: ShoppingListItemModel
    let catalogItem: UnifiedCatalogItem
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags

    /// All tags combined (manufacturer + user tags)
    nonisolated var allTags: [String] {
        Array(Set(tags + userTags)).sorted()
    }

    /// Priority score based on shortfall percentage
    nonisolated var priorityScore: Double {
        guard shoppingListItem.minimumQuantity > 0 else { return 0 }
        return shoppingListItem.neededQuantity / shoppingListItem.minimumQuantity
    }

    /// Complete item model for navigation purposes
    /// Note: inventory will be empty for shopping list items
    nonisolated var completeItem: CompleteInventoryItemModel {
        CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: tags,
            userTags: userTags
        )
    }

    /// Backward compatibility: access as GlassItemModel
    /// Returns nil if this is a coating or tool item
    nonisolated var glassItem: GlassItemModel? {
        guard catalogItem.itemType == .glass else { return nil }
        return GlassItemModel(
            stable_id: catalogItem.stable_id,
            name: catalogItem.name,
            sku: catalogItem.sku,
            manufacturer: catalogItem.manufacturer,
            mfr_notes: catalogItem.mfr_notes,
            coe: catalogItem.coe ?? 0,
            url: catalogItem.url,
            mfr_status: catalogItem.mfr_status,
            image_url: catalogItem.image_url,
            image_path: catalogItem.image_path,
            image_thumb_path: catalogItem.image_thumb_path,
            dominant_colors: catalogItem.dominant_colors,
            image_urls: catalogItem.image_urls,
            image_paths: catalogItem.image_paths,
            image_thumb_paths: catalogItem.image_thumb_paths
        )
    }
}

/// Low stock report with actionable information
struct LowStockReportModel {
    let items: [DetailedLowStockItemModel]
    let groupedByStore: [String: [DetailedLowStockItemModel]]
    let totalItemsLow: Int
    let totalShortfall: Double
    let storesAffected: Int
    let generatedAt: Date

    /// Business Logic: Aggregate low stock items and calculate statistics
    /// - Parameter items: Low stock items to aggregate
    /// - Returns: Low stock report with grouped items and summary statistics
    ///
    /// Business rules:
    /// - Group items by store for shopping organization
    /// - Calculate total shortfall across all items
    /// - Count unique stores affected
    nonisolated static func from(items: [DetailedLowStockItemModel]) -> LowStockReportModel {
        // Group by store for shopping organization
        let groupedByStore = Dictionary(grouping: items) { $0.lowStockItem.store }

        // Calculate summary statistics
        let totalItemsLow = items.count
        let totalShortfall = items.reduce(0.0) { $0 + $1.lowStockItem.shortfall }
        let storesAffected = Set(items.map { $0.lowStockItem.store }).count

        return LowStockReportModel(
            items: items,
            groupedByStore: groupedByStore,
            totalItemsLow: totalItemsLow,
            totalShortfall: totalShortfall,
            storesAffected: storesAffected,
            generatedAt: Date()
        )
    }
}

/// Low stock item with complete context
struct DetailedLowStockItemModel {
    let lowStockItem: LowStockItemModel
    let catalogItem: UnifiedCatalogItem
    let tags: [String]

    /// Urgency level based on how far below minimum we are
    nonisolated var urgencyLevel: UrgencyLevel {
        let shortfallPercentage = lowStockItem.shortfall / lowStockItem.minimumQuantity
        if shortfallPercentage >= 0.8 {
            return .critical
        } else if shortfallPercentage >= 0.5 {
            return .high
        } else if shortfallPercentage >= 0.2 {
            return .medium
        } else {
            return .low
        }
    }

    /// Backward compatibility: access as GlassItemModel
    /// Returns nil if this is a coating or tool item
    nonisolated var glassItem: GlassItemModel? {
        guard catalogItem.itemType == .glass else { return nil }
        return GlassItemModel(
            stable_id: catalogItem.stable_id,
            name: catalogItem.name,
            sku: catalogItem.sku,
            manufacturer: catalogItem.manufacturer,
            mfr_notes: catalogItem.mfr_notes,
            coe: catalogItem.coe ?? 0,
            url: catalogItem.url,
            mfr_status: catalogItem.mfr_status,
            image_url: catalogItem.image_url,
            image_path: catalogItem.image_path,
            image_thumb_path: catalogItem.image_thumb_path,
            dominant_colors: catalogItem.dominant_colors,
            image_urls: catalogItem.image_urls,
            image_paths: catalogItem.image_paths,
            image_thumb_paths: catalogItem.image_thumb_paths
        )
    }
}

extension DetailedLowStockItemModel: Comparable {
    /// Business Logic: Sort by shortfall descending (highest shortfall first), then by item_stable_id for stable ordering
    /// Business rule: Items with highest shortfall are most urgent and should appear first
    nonisolated static func < (lhs: DetailedLowStockItemModel, rhs: DetailedLowStockItemModel) -> Bool {
        // Higher shortfall = "less than" (sorts first)
        if lhs.lowStockItem.shortfall != rhs.lowStockItem.shortfall {
            return lhs.lowStockItem.shortfall > rhs.lowStockItem.shortfall
        }
        // Tiebreaker: sort by item_stable_id then type for stable ordering
        if lhs.lowStockItem.item_stable_id != rhs.lowStockItem.item_stable_id {
            return lhs.lowStockItem.item_stable_id < rhs.lowStockItem.item_stable_id
        }
        return lhs.lowStockItem.type < rhs.lowStockItem.type
    }

    nonisolated static func == (lhs: DetailedLowStockItemModel, rhs: DetailedLowStockItemModel) -> Bool {
        return lhs.lowStockItem.item_stable_id == rhs.lowStockItem.item_stable_id &&
               lhs.lowStockItem.type == rhs.lowStockItem.type
    }
}

/// Minimum with complete context
struct DetailedMinimumModel: Sendable {
    let minimum: ItemMinimumModel
    let catalogItem: UnifiedCatalogItem
    let tags: [String]
    let currentQuantity: Double

    /// Whether current inventory meets the minimum
    nonisolated var meetsMinimum: Bool {
        currentQuantity >= minimum.quantity
    }

    /// How much more is needed to meet minimum
    nonisolated var shortfall: Double {
        max(0, minimum.quantity - currentQuantity)
    }

    /// Backward compatibility: access as GlassItemModel
    /// Returns nil if this is a coating or tool item
    nonisolated var glassItem: GlassItemModel? {
        guard catalogItem.itemType == .glass else { return nil }
        return GlassItemModel(
            stable_id: catalogItem.stable_id,
            name: catalogItem.name,
            sku: catalogItem.sku,
            manufacturer: catalogItem.manufacturer,
            mfr_notes: catalogItem.mfr_notes,
            coe: catalogItem.coe ?? 0,
            url: catalogItem.url,
            mfr_status: catalogItem.mfr_status,
            image_url: catalogItem.image_url,
            image_path: catalogItem.image_path,
            image_thumb_path: catalogItem.image_thumb_path,
            dominant_colors: catalogItem.dominant_colors,
            image_urls: catalogItem.image_urls,
            image_paths: catalogItem.image_paths,
            image_thumb_paths: catalogItem.image_thumb_paths
        )
    }
}

/// Store utilization statistics
struct StoreStatisticsModel: Sendable {
    let storeName: String
    let minimumCount: Int
    let currentNeedsCount: Int
    let totalNeededQuantity: Double

    /// Percentage of minimums that currently need restocking
    nonisolated var restockingPercentage: Double {
        guard minimumCount > 0 else { return 0 }
        return Double(currentNeedsCount) / Double(minimumCount) * 100.0
    }
}

/// Comprehensive minimum analytics
struct MinimumAnalyticsModel {
    let basicStatistics: MinimumQuantityStatistics
    let commonTypes: [String: Int]
    let storeDistribution: [String: Int]
    let highestMinimums: [ItemMinimumModel]
}

/// Urgency levels for low stock items
enum UrgencyLevel: String, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}

// MARK: - Sorting Logic (Business Rules)

extension DetailedShoppingListItemModel: Comparable {
    /// Sort shopping list items by neededQuantity (descending), then by item_stable_id (ascending) for stable ordering
    /// Business rule: Items with highest need should appear first
    nonisolated static func < (lhs: DetailedShoppingListItemModel, rhs: DetailedShoppingListItemModel) -> Bool {
        // Higher neededQuantity is "less than" for descending sort
        if lhs.shoppingListItem.neededQuantity != rhs.shoppingListItem.neededQuantity {
            return lhs.shoppingListItem.neededQuantity > rhs.shoppingListItem.neededQuantity
        }
        // Tiebreaker: sort by item_stable_id alphabetically for stable ordering
        return lhs.shoppingListItem.item_stable_id < rhs.shoppingListItem.item_stable_id
    }

    nonisolated static func == (lhs: DetailedShoppingListItemModel, rhs: DetailedShoppingListItemModel) -> Bool {
        return lhs.shoppingListItem.item_stable_id == rhs.shoppingListItem.item_stable_id
    }
}

extension DetailedMinimumModel: Comparable {
    /// Sort minimums by type (alphabetically ascending), then by item_stable_id for stable ordering
    /// Business rule: Alphabetical ordering for consistent display
    nonisolated static func < (lhs: DetailedMinimumModel, rhs: DetailedMinimumModel) -> Bool {
        // Sort by type first
        if lhs.minimum.type != rhs.minimum.type {
            return lhs.minimum.type < rhs.minimum.type
        }
        // Tiebreaker: sort by item_stable_id for stable ordering
        return lhs.minimum.item_stable_id < rhs.minimum.item_stable_id
    }

    nonisolated static func == (lhs: DetailedMinimumModel, rhs: DetailedMinimumModel) -> Bool {
        lhs.minimum.item_stable_id == rhs.minimum.item_stable_id && lhs.minimum.type == rhs.minimum.type
    }
}

extension StoreStatisticsModel: Comparable {
    /// Sort stores by currentNeedsCount (descending), then by storeName (ascending) for stable ordering
    /// Business rule: Stores with highest needs should appear first (priority ordering)
    nonisolated static func < (lhs: StoreStatisticsModel, rhs: StoreStatisticsModel) -> Bool {
        // Higher currentNeedsCount is "less than" for descending sort
        if lhs.currentNeedsCount != rhs.currentNeedsCount {
            return lhs.currentNeedsCount > rhs.currentNeedsCount
        }
        // Tiebreaker: sort by storeName alphabetically for stable ordering
        return lhs.storeName < rhs.storeName
    }

    nonisolated static func == (lhs: StoreStatisticsModel, rhs: StoreStatisticsModel) -> Bool {
        return lhs.storeName == rhs.storeName
    }
}
