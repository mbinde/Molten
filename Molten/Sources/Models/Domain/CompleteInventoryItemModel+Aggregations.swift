//
//  CompleteInventoryItemModel+Aggregations.swift
//  Molten
//
//  Aggregation logic: totals, groupings, computed values
//  Part of CompleteInventoryItemModel split to maintain <200 LOC per file
//

import Foundation

// MARK: - Inventory Aggregations

extension CompleteInventoryItemModel {

    // MARK: - Totals

    /// Total quantity across all inventory records
    ///
    /// Business rule: Sum of all inventory record quantities
    /// Performance: O(n) where n = number of inventory records
    nonisolated var totalQuantity: Double {
        inventory.reduce(0.0) { $0 + $1.quantity }
    }

    /// Total container count across all inventory records (for jar-based tracking)
    ///
    /// Business rule: Sum of all container counts
    /// Performance: O(n) where n = number of inventory records
    nonisolated var totalContainerCount: Double {
        inventory.reduce(0.0) { $0 + ($1.containerCount ?? 0) }
    }

    // MARK: - Groupings

    /// Inventory grouped by type with total quantities
    ///
    /// Returns dictionary mapping type → total quantity for that type
    /// Example: ["rod": 25.0, "tube": 10.0, "frit": 5.0]
    ///
    /// Business rule: Aggregate inventory by type (rod, tube, frit, etc.)
    /// Performance: O(n) where n = number of inventory records
    nonisolated var inventoryByType: [String: Double] {
        Dictionary(grouping: inventory, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    /// Inventory grouped by location with total quantities
    ///
    /// Returns dictionary mapping location → total quantity at that location
    /// Example: ["Studio A": 15.0, "Storage Room": 20.0]
    ///
    /// Business rule: Aggregate inventory by physical location
    /// Performance: O(n) where n = number of inventory records with locations
    nonisolated var inventoryByLocation: [String: Double] {
        Dictionary(grouping: inventory.filter { $0.location != nil }, by: { $0.location! })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    // MARK: - Location Helpers

    /// Unique locations across all inventory records (sorted alphabetically)
    ///
    /// Returns array of location names where this item is stored
    /// Example: ["Storage Room", "Studio A", "Studio B"]
    ///
    /// Business rule: All distinct locations containing this item
    /// Performance: O(n log n) where n = number of unique locations
    nonisolated var locations: [String] {
        Array(Set(inventory.compactMap { $0.location })).sorted()
    }
}
