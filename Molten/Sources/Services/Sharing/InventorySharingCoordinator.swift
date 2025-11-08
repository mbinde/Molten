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
        let primaryType = item.inventory.first?.type ?? "unknown"

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
    /// - Parameters:
    ///   - items: Inventory items to share
    ///   - metadata: Display name and notes to share publicly
    /// - Returns: Generated share code
    func shareMyInventory(items: [CompleteInventoryItemModel], metadata: MyShareMetadata) async throws -> String {
        // Filter out items with zero quantity
        let nonZeroItems = items.filter { $0.totalQuantity > 0 }

        // Convert to snapshots
        let snapshots = convertToSnapshots(items: nonZeroItems)

        // Create share
        return try await sharingService.createShare(items: snapshots, metadata: metadata)
    }

    // MARK: - Download Friend's Inventory

    /// Download friend's inventory by share code
    /// - Parameter shareCode: Friend's share code
    /// - Returns: Snapshot result with validity flag
    func downloadFriendInventory(shareCode: String) async throws -> SnapshotResult {
        return try await sharingService.downloadFriendInventory(shareCode: shareCode)
    }

    // MARK: - Update My Share

    /// Update my existing share with new inventory data and/or metadata
    /// - Parameters:
    ///   - shareCode: My share code
    ///   - items: Updated inventory items
    ///   - metadata: Updated display name and notes
    func updateMyShare(shareCode: String, items: [CompleteInventoryItemModel], metadata: MyShareMetadata) async throws {
        // Filter out items with zero quantity
        let nonZeroItems = items.filter { $0.totalQuantity > 0 }

        // Convert to snapshots
        let snapshots = convertToSnapshots(items: nonZeroItems)

        // Update share
        try await sharingService.updateShare(shareCode: shareCode, items: snapshots, metadata: metadata)
    }

    // MARK: - Delete My Share

    /// Delete my share
    /// - Parameter shareCode: My share code to delete
    func deleteMyShare(shareCode: String) async throws {
        try await sharingService.deleteShare(shareCode: shareCode)
    }
}
