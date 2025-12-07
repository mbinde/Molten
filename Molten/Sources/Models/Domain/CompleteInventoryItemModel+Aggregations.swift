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
    /// Uses StorageLocation records if available, falls back to Inventory.location for legacy data
    nonisolated var inventoryByLocation: [String: Double] {
        // Use StorageLocation if available (new architecture)
        if !storageLocations.isEmpty {
            print("📍 [StorageLocation] Using StorageLocation data for inventoryByLocation (\(catalogItem.name))")
            return Dictionary(grouping: storageLocations.filter { !$0.locationName.isEmpty }, by: { $0.locationName })
                .mapValues { locations in
                    locations.reduce(0.0) { $0 + $1.quantity }
                }
        }
        // Fallback to Inventory.location for legacy data
        print("⚠️ [StorageLocation] Falling back to Inventory.location for inventoryByLocation (\(catalogItem.name))")
        return Dictionary(grouping: inventory.filter { $0.location != nil }, by: { $0.location! })
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
    /// Uses StorageLocation records if available, falls back to Inventory.location for legacy data
    nonisolated var locations: [String] {
        // Use StorageLocation if available (new architecture)
        if !storageLocations.isEmpty {
            // Note: Not logging here since this is called frequently (use inventoryByLocation log instead)
            return Array(Set(storageLocations.map { $0.locationName }.filter { !$0.isEmpty })).sorted()
        }
        // Fallback to Inventory.location for legacy data
        // Note: Not logging here since this is called frequently (use inventoryByLocation log instead)
        return Array(Set(inventory.compactMap { $0.location })).sorted()
    }

    /// Storage locations grouped by location definition ID
    ///
    /// Returns dictionary mapping storageLocationId → StorageLocationModels
    /// Used for filtering and location-based operations
    nonisolated var storageLocationsByDefinition: [UUID: [StorageLocationModel]] {
        Dictionary(grouping: storageLocations.filter { $0.storageLocationId != nil }, by: { $0.storageLocationId! })
    }
}
