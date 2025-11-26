//
//  CompleteInventoryItemModel+Queries.swift
//  Molten
//
//  Query logic: filtering, sorting, business logic predicates
//  Part of CompleteInventoryItemModel split to maintain <200 LOC per file
//

import Foundation

// MARK: - Inventory Queries

extension CompleteInventoryItemModel {

    // MARK: - Business Logic Queries

    /// Whether this item has any inventory (quantity > 0 OR containerCount > 0)
    ///
    /// Business rule: Item "has inventory" if ANY inventory record has stock
    /// (positive quantity OR positive container count for jar-based tracking)
    ///
    /// Example: [Record(qty: 5, jars: 0)] → true
    /// Example: [Record(qty: 0, jars: 2)] → true (jar-only tracking)
    /// Example: [Record(qty: 0, jars: 0)] → false
    /// Example: [] → false
    ///
    /// Performance: O(n) worst case, but short-circuits on first positive value
    nonisolated var hasInventory: Bool {
        inventory.contains { $0.hasStock }
    }

    // MARK: - UI Display Helpers

    /// Product type as string for UI display
    ///
    /// Returns the raw value of the item type enum
    /// Example: "glassItem", "customItem"
    ///
    /// Use this for UI labels, filtering, grouping in views
    nonisolated var productType: String {
        catalogItem.itemType.rawValue
    }

    // MARK: - Future Query Extensions
    //
    // Add filtering, sorting, and business logic queries here:
    //
    // Examples:
    // - func matchesSearch(_ query: String) -> Bool
    // - var isLowStock: Bool (based on minimums)
    // - var needsReorder: Bool (business logic)
    // - static func sorted(by: SortOption) -> [CompleteInventoryItemModel]
}
