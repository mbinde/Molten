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
nonisolated struct DetailedShoppingListModel {
    let store: String
    let items: [DetailedShoppingListItemModel]
    let totalItems: Int
    let totalValue: Double

    /// Items grouped by manufacturer for easier shopping
    nonisolated var itemsByManufacturer: [String: [DetailedShoppingListItemModel]] {
        Dictionary(grouping: items) { $0.glassItem.manufacturer }
    }
}

/// Shopping list item with complete glass item information
nonisolated struct DetailedShoppingListItemModel {
    let shoppingListItem: ShoppingListItemModel
    let glassItem: GlassItemModel
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
            glassItem: glassItem,
            inventory: [],
            tags: tags,
            userTags: userTags
        )
    }
}

/// Low stock report with actionable information
nonisolated struct LowStockReportModel {
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
    static func from(items: [DetailedLowStockItemModel]) -> LowStockReportModel {
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
nonisolated struct DetailedLowStockItemModel {
    let lowStockItem: LowStockItemModel
    let glassItem: GlassItemModel
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
}

/// Minimum with complete context
nonisolated struct DetailedMinimumModel {
    let minimum: ItemMinimumModel
    let glassItem: GlassItemModel
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
}

/// Store utilization statistics
nonisolated struct StoreStatisticsModel {
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
nonisolated struct MinimumAnalyticsModel {
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
    /// Sort shopping list items by neededQuantity (descending)
    /// Business rule: Items with highest need should appear first
    static func < (lhs: DetailedShoppingListItemModel, rhs: DetailedShoppingListItemModel) -> Bool {
        // Higher neededQuantity is "less than" for descending sort
        return lhs.shoppingListItem.neededQuantity > rhs.shoppingListItem.neededQuantity
    }

    static func == (lhs: DetailedShoppingListItemModel, rhs: DetailedShoppingListItemModel) -> Bool {
        return lhs.shoppingListItem.item_stable_id == rhs.shoppingListItem.item_stable_id
    }
}

extension DetailedMinimumModel: Comparable {
    /// Sort minimums by type (alphabetically ascending)
    /// Business rule: Alphabetical ordering for consistent display
    static func < (lhs: DetailedMinimumModel, rhs: DetailedMinimumModel) -> Bool {
        lhs.minimum.type < rhs.minimum.type
    }

    static func == (lhs: DetailedMinimumModel, rhs: DetailedMinimumModel) -> Bool {
        lhs.minimum.item_stable_id == rhs.minimum.item_stable_id && lhs.minimum.type == rhs.minimum.type
    }
}

extension StoreStatisticsModel: Comparable {
    /// Sort stores by currentNeedsCount (descending)
    /// Business rule: Stores with highest needs should appear first (priority ordering)
    static func < (lhs: StoreStatisticsModel, rhs: StoreStatisticsModel) -> Bool {
        // Higher currentNeedsCount is "less than" for descending sort
        return lhs.currentNeedsCount > rhs.currentNeedsCount
    }

    static func == (lhs: StoreStatisticsModel, rhs: StoreStatisticsModel) -> Bool {
        return lhs.storeName == rhs.storeName
    }
}
