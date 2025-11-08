//
//  InventorySharingCoordinator.swift
//  Molten
//
//  Bridges app inventory with sharing system
//  Converts between CompleteInventoryItemModel and InventoryItemSnapshot
//

import Foundation

/// Coordinates inventory sharing with the app's inventory system
@MainActor
class InventorySharingCoordinator {

    // MARK: - Properties

    private let sharingService: InventorySharingService

    // MARK: - Initialization

    init(sharingService: InventorySharingService = InventorySharingService()) {
        self.sharingService = sharingService
    }

    // MARK: - Conversion

    /// Convert app inventory item to snapshot format
    /// - Parameter item: Complete inventory item from app
    /// - Returns: Inventory item snapshot for sharing
    func convertToSnapshot(item: CompleteInventoryItemModel) -> InventoryItemSnapshot {
        // Get primary inventory type (most common type)
        let primaryType = item.inventory.first?.inventoryType ?? "unknown"

        // Get primary location (first non-nil location)
        let primaryLocation = item.inventory.first(where: { $0.location != nil })?.location

        return InventoryItemSnapshot(
            stableId: item.catalogItem.stable_id,
            manufacturer: item.catalogItem.manufacturer,
            sku: item.catalogItem.sku ?? "",
            quantity: item.totalQuantity,
            unit: primaryType,
            location: primaryLocation
        )
    }

    /// Convert multiple items to snapshots
    /// - Parameter items: Complete inventory items
    /// - Returns: Array of inventory item snapshots
    func convertToSnapshots(items: [CompleteInventoryItemModel]) -> [InventoryItemSnapshot] {
        return items.map { convertToSnapshot(item: $0) }
    }

    // MARK: - Share My Inventory

    /// Create a share of my inventory
    /// - Parameter items: Inventory items to share
    /// - Returns: Generated share code
    func shareMyInventory(items: [CompleteInventoryItemModel]) async throws -> String {
        // Filter out items with zero quantity
        let nonZeroItems = items.filter { $0.totalQuantity > 0 }

        // Convert to snapshots
        let snapshots = convertToSnapshots(items: nonZeroItems)

        // Create share
        return try await sharingService.createShare(items: snapshots)
    }

    // MARK: - Download Friend's Inventory

    /// Download friend's inventory by share code
    /// - Parameter shareCode: Friend's share code
    /// - Returns: Snapshot result with validity flag
    func downloadFriendInventory(shareCode: String) async throws -> SnapshotResult {
        return try await sharingService.downloadFriendInventory(shareCode: shareCode)
    }

    // MARK: - Update My Share

    /// Update my existing share with new inventory data
    /// - Parameters:
    ///   - shareCode: My share code
    ///   - items: Updated inventory items
    func updateMyShare(shareCode: String, items: [CompleteInventoryItemModel]) async throws {
        // Filter out items with zero quantity
        let nonZeroItems = items.filter { $0.totalQuantity > 0 }

        // Convert to snapshots
        let snapshots = convertToSnapshots(items: nonZeroItems)

        // Update share
        try await sharingService.updateShare(shareCode: shareCode, items: snapshots)
    }

    // MARK: - Delete My Share

    /// Delete my share
    /// - Parameter shareCode: My share code to delete
    func deleteMyShare(shareCode: String) async throws {
        try await sharingService.deleteShare(shareCode: shareCode)
    }
}
