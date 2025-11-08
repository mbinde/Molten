//
//  InventorySharingManager.swift
//  Molten
//
//  High-level manager for inventory sharing
//  Orchestrates coordinator and metadata repository
//

import Foundation

/// High-level manager for inventory sharing operations
@MainActor
class InventorySharingManager {

    // MARK: - Properties

    private let coordinator: InventorySharingCoordinator
    private let metadataRepository: ShareMetadataRepository

    // MARK: - Initialization

    init(
        coordinator: InventorySharingCoordinator = InventorySharingCoordinator(),
        metadataRepository: ShareMetadataRepository = ShareMetadataRepository()
    ) {
        self.coordinator = coordinator
        self.metadataRepository = metadataRepository
    }

    // MARK: - My Share

    /// Create a new share of my inventory
    /// - Parameter items: Inventory items to share
    /// - Returns: Generated share code
    /// - Throws: SharingManagerError.shareAlreadyExists if share already exists
    func createMyShare(items: [CompleteInventoryItemModel]) async throws -> String {
        // Check if share already exists
        if metadataRepository.getMyShareCode() != nil {
            throw SharingManagerError.shareAlreadyExists
        }

        // Create share
        let shareCode = try await coordinator.shareMyInventory(items: items)

        // Save share code locally
        try metadataRepository.saveMyShareCode(shareCode)

        return shareCode
    }

    /// Refresh my existing share with updated inventory
    /// - Parameter items: Updated inventory items
    /// - Throws: SharingManagerError.noShareExists if no share exists
    func refreshMyShare(items: [CompleteInventoryItemModel]) async throws {
        // Get existing share code
        guard let shareCode = metadataRepository.getMyShareCode() else {
            throw SharingManagerError.noShareExists
        }

        // Update share
        try await coordinator.updateMyShare(shareCode: shareCode, items: items)
    }

    /// Delete my share
    /// - Throws: SharingManagerError.noShareExists if no share exists
    func deleteMyShare() async throws {
        // Get existing share code
        guard let shareCode = metadataRepository.getMyShareCode() else {
            throw SharingManagerError.noShareExists
        }

        // Delete from server
        try await coordinator.deleteMyShare(shareCode: shareCode)

        // Remove local code
        try metadataRepository.deleteMyShareCode()
    }

    /// Get my current share code
    /// - Returns: Share code if exists, nil otherwise
    func getMyShareCode() -> String? {
        return metadataRepository.getMyShareCode()
    }

    // MARK: - Friend Shares

    /// Add a friend's share by downloading it
    /// - Parameters:
    ///   - shareCode: Friend's share code
    ///   - friendName: Display name for this friend
    /// - Returns: Snapshot result with validity flag
    func addFriendShare(shareCode: String, friendName: String) async throws -> SnapshotResult {
        // Download friend's inventory
        let result = try await coordinator.downloadFriendInventory(shareCode: shareCode)

        // Save friend share metadata
        let friendShare = FriendShare(
            shareCode: shareCode,
            friendName: friendName,
            dateAdded: Date(),
            lastRefreshed: Date()
        )
        try metadataRepository.saveFriendShare(friendShare)

        return result
    }

    /// Refresh a friend's share
    /// - Parameter shareCode: Friend's share code
    /// - Returns: Updated snapshot result
    /// - Throws: SharingManagerError.friendShareNotFound if friend share doesn't exist
    func refreshFriendShare(shareCode: String) async throws -> SnapshotResult {
        // Check if friend share exists
        guard let existingShare = metadataRepository.getFriendShare(shareCode: shareCode) else {
            throw SharingManagerError.friendShareNotFound
        }

        // Download updated inventory
        let result = try await coordinator.downloadFriendInventory(shareCode: shareCode)

        // Update last refreshed timestamp
        let updatedShare = FriendShare(
            shareCode: existingShare.shareCode,
            friendName: existingShare.friendName,
            dateAdded: existingShare.dateAdded,
            lastRefreshed: Date()
        )
        try metadataRepository.saveFriendShare(updatedShare)

        return result
    }

    /// Remove a friend's share
    /// - Parameter shareCode: Friend's share code to remove
    func removeFriendShare(shareCode: String) throws {
        try metadataRepository.deleteFriendShare(shareCode: shareCode)
    }

    /// Get all friend shares
    /// - Returns: Array of friend shares
    func getFriendShares() -> [FriendShare] {
        return metadataRepository.getFriendShares()
    }

    /// Get a specific friend share
    /// - Parameter shareCode: Friend's share code
    /// - Returns: Friend share if found, nil otherwise
    func getFriendShare(shareCode: String) -> FriendShare? {
        return metadataRepository.getFriendShare(shareCode: shareCode)
    }
}
