//
//  InventorySharingManager.swift
//  Molten
//
//  High-level manager for inventory sharing
//  Orchestrates coordinator and metadata repository
//
//  AUTOMATIC DELETION POLICY:
//  Shares are automatically deleted from the server 90 days after your last inventory update.
//  - Creating a share: Starts 90-day countdown from creation timestamp
//  - Updating inventory: Resets countdown to 90 days from update timestamp
//  - Friend downloads: Do NOT reset the countdown
//  To keep your share active, update your inventory at least once every 90 days.
//

import Foundation
import CoreData

/// High-level manager for inventory sharing operations
@MainActor
class InventorySharingManager {

    // MARK: - Properties

    private let coordinator: InventorySharingCoordinator
    private let metadataRepository: ShareMetadataRepository  // For "my share code" only
    private let shareRecordRepository: CoreDataShareRecordRepository  // For friend shares (Cloud)
    private let sharedInventoryRepository: CoreDataSharedInventoryRepository  // For friend inventory cache (Local)

    // MARK: - Initialization

    /// Initialize with explicit dependencies (for testing)
    init(
        coordinator: InventorySharingCoordinator,
        metadataRepository: ShareMetadataRepository,
        shareRecordRepository: CoreDataShareRecordRepository,
        sharedInventoryRepository: CoreDataSharedInventoryRepository
    ) {
        self.coordinator = coordinator
        self.metadataRepository = metadataRepository
        self.shareRecordRepository = shareRecordRepository
        self.sharedInventoryRepository = sharedInventoryRepository
    }

    /// Convenience init using AppDependencies (default for production/tests)
    convenience init(deps: AppDependencies = AppDependencies.shared) {
        let coordinator = InventorySharingCoordinator()
        let metadataRepository = ShareMetadataRepository()

        // Use cloud context for share records (synced across devices)
        let shareRecordRepository = CoreDataShareRecordRepository(
            context: deps.persistenceController.cloudContext ?? deps.persistenceController.container.viewContext
        )

        // Use local context for cached inventory, with catalog repository from deps
        let sharedInventoryRepository = CoreDataSharedInventoryRepository(
            context: deps.persistenceController.localContext ?? deps.persistenceController.container.viewContext,
            catalogRepository: deps.glassItemRepository
        )

        self.init(
            coordinator: coordinator,
            metadataRepository: metadataRepository,
            shareRecordRepository: shareRecordRepository,
            sharedInventoryRepository: sharedInventoryRepository
        )
    }

    // MARK: - My Share

    /// Create a new share of my inventory
    /// - Parameters:
    ///   - items: Inventory items to share
    ///   - metadata: Display name and notes to share publicly
    /// - Returns: Generated share code
    /// - Throws: SharingManagerError.shareAlreadyExists if share already exists
    func createMyShare(items: [CompleteInventoryItemModel], metadata: MyShareMetadata) async throws -> String {
        // Check if share already exists
        if metadataRepository.getMyShareCode() != nil {
            throw SharingManagerError.shareAlreadyExists
        }

        // Create share
        let shareCode = try await coordinator.shareMyInventory(items: items, metadata: metadata)

        // Save share code and metadata locally
        try metadataRepository.saveMyShareCode(shareCode)
        try metadataRepository.saveMyShareMetadata(metadata)

        return shareCode
    }

    /// Refresh my existing share with updated inventory and/or metadata
    /// - Parameters:
    ///   - items: Updated inventory items
    ///   - metadata: Optional updated metadata (if nil, keeps existing)
    /// - Throws: SharingManagerError.noShareExists if no share exists
    func refreshMyShare(items: [CompleteInventoryItemModel], metadata: MyShareMetadata? = nil) async throws {
        // Get existing share code
        guard let shareCode = metadataRepository.getMyShareCode() else {
            throw SharingManagerError.noShareExists
        }

        // Use provided metadata or fall back to existing
        let shareMetadata = metadata ?? metadataRepository.getMyShareMetadata() ?? MyShareMetadata(displayName: "")

        // Update share
        try await coordinator.updateMyShare(shareCode: shareCode, items: items, metadata: shareMetadata)

        // Save metadata if provided
        if let newMetadata = metadata {
            try metadataRepository.saveMyShareMetadata(newMetadata)
        }
    }

    /// Get my share metadata
    func getMyShareMetadata() -> MyShareMetadata? {
        return metadataRepository.getMyShareMetadata()
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

    /// Delete only the local share metadata without contacting the server
    /// Use this when server deletion fails (e.g., due to key pair mismatch)
    /// - Throws: SharingManagerError.noShareExists if no share exists
    func deleteLocalShareOnly() throws {
        guard metadataRepository.getMyShareCode() != nil else {
            throw SharingManagerError.noShareExists
        }

        // Remove local code only
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
    ///   - nickname: Optional personal nickname for this friend
    /// - Returns: Snapshot result with validity flag
    func addFriendShare(
        shareCode: String,
        nickname: String? = nil
    ) async throws -> SnapshotResult {
        // Download friend's inventory
        let result = try await coordinator.downloadFriendInventory(shareCode: shareCode)

        // Always use display name from server
        let ownerName = result.ownerName ?? "Unknown"

        // Generate random icon colors for new friend
        let randomColors = generateRandomIconColors()

        // Save share record to Core Data (Cloud - syncs across devices)
        // Includes owner's metadata from server (owner_name, owner_share_notes)
        try shareRecordRepository.saveShareRecord(
            shareCode: shareCode,
            ownerName: ownerName,
            ownerNickname: nickname,
            ownerShareNotes: result.ownerShareNotes,
            iconSymbol: randomColors.symbol,
            iconBackgroundHex: randomColors.backgroundHex,
            iconForegroundHex: randomColors.foregroundHex
        )

        // Save inventory snapshot to Core Data (Local - cached for offline access)
        try sharedInventoryRepository.saveSnapshot(shareCode: shareCode, items: result.items)

        return result
    }

    /// Generate random icon colors for a new friend
    private func generateRandomIconColors() -> (symbol: String, backgroundHex: String, foregroundHex: String) {
        let symbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill", "star.fill", "heart.fill"]
        let colors = [
            "#FF3B30", // Red
            "#FF9500", // Orange
            "#FFCC00", // Yellow
            "#34C759", // Green
            "#00C7BE", // Teal
            "#30B0C7", // Cyan
            "#007AFF", // Blue
            "#5856D6", // Purple
            "#AF52DE", // Magenta
            "#FF2D55"  // Pink
        ]

        let randomSymbol = symbols.randomElement() ?? "circle.fill"
        let randomBackgroundHex = colors.randomElement() ?? "#007AFF"
        let foregroundHex = "#FFFFFF" // Always white for good contrast

        return (randomSymbol, randomBackgroundHex, foregroundHex)
    }

    /// Refresh a friend's share
    /// - Parameter shareCode: Friend's share code
    /// - Returns: Updated snapshot result
    /// - Throws: SharingManagerError.friendShareNotFound if friend share doesn't exist
    /// - Throws: SharingManagerError.shareDeletedByOwner if share was deleted by owner (404)
    func refreshFriendShare(shareCode: String) async throws -> SnapshotResult {
        // Check if share record exists and is active
        guard let shareRecord = try shareRecordRepository.getShareRecord(shareCode: shareCode),
              shareRecord.value(forKey: "status") as? String == "active" else {
            throw SharingManagerError.friendShareNotFound
        }

        do {
            // Download updated inventory
            print("🔐 [REFRESH] Downloading friend inventory for share code: \(shareCode)")
            let result = try await coordinator.downloadFriendInventory(shareCode: shareCode)

            // Update last fetched timestamp
            try shareRecordRepository.updateLastFetched(shareCode: shareCode)

            // Update inventory snapshot in Core Data (Local)
            try sharedInventoryRepository.saveSnapshot(shareCode: shareCode, items: result.items)

            print("🔐 [REFRESH] Successfully refreshed friend share")
            return result

        } catch SharingAPIError.notFound {
            // Share was deleted by owner - clean up cached data
            print("🔐 [REFRESH] Share not found (404) - owner deleted it. Cleaning up cached data...")

            // Mark share record as inactive
            try shareRecordRepository.deactivateShareRecord(shareCode: shareCode)

            // Delete cached inventory snapshot
            try sharedInventoryRepository.deleteSnapshot(shareCode: shareCode)

            print("🔐 [REFRESH] Cached data cleaned up")
            throw SharingManagerError.shareDeletedByOwner
        }
    }

    /// Remove a friend's share (marks as inactive, preserves history)
    /// - Parameter shareCode: Friend's share code to remove
    func removeFriendShare(shareCode: String) throws {
        // Mark share record as inactive (soft delete - preserves history for CloudKit sync)
        try shareRecordRepository.deactivateShareRecord(shareCode: shareCode)

        // Delete cached inventory snapshot from Local store
        try sharedInventoryRepository.deleteSnapshot(shareCode: shareCode)
    }

    /// Get all active friend shares
    /// - Returns: Array of active FriendShare structs
    func getFriendShares() -> [FriendShare] {
        do {
            let shareRecords = try shareRecordRepository.getActiveShareRecords()
            return shareRecords.compactMap { $0.toFriendShare() }
        } catch {
            return []
        }
    }

    /// Get a specific friend share
    /// - Parameter shareCode: Friend's share code
    /// - Returns: FriendShare if found, nil otherwise
    func getFriendShare(shareCode: String) -> FriendShare? {
        do {
            guard let shareRecord = try shareRecordRepository.getShareRecord(shareCode: shareCode),
                  shareRecord.value(forKey: "status") as? String == "active" else {
                return nil
            }
            return shareRecord.toFriendShare()
        } catch {
            return nil
        }
    }

    /// Get all active friend share records (Core Data entities)
    /// - Returns: Array of active ShareRecord entities
    func getActiveShareRecords() throws -> [ShareRecord] {
        return try shareRecordRepository.getActiveShareRecords()
    }

    /// Get a specific share record (Core Data entity)
    /// - Parameter shareCode: Friend's share code
    /// - Returns: ShareRecord if found, nil otherwise
    func getShareRecord(shareCode: String) throws -> ShareRecord? {
        return try shareRecordRepository.getShareRecord(shareCode: shareCode)
    }

    // MARK: - Friend Share Customization

    /// Update your personal nickname for a friend
    /// - Parameters:
    ///   - shareCode: Friend's share code
    ///   - nickname: Personal nickname (e.g., "Alice from GAS 2025")
    func updateFriendNickname(shareCode: String, nickname: String?) throws {
        try shareRecordRepository.updateOwnerNickname(shareCode: shareCode, nickname: nickname)
    }

    /// Update your personal notes about a friend's share
    /// - Parameters:
    ///   - shareCode: Friend's share code
    ///   - notes: Personal notes (e.g., "Met at GAS 2025, specializes in boro")
    func updateFriendNotes(shareCode: String, notes: String?) throws {
        try shareRecordRepository.updateUserShareNotes(shareCode: shareCode, notes: notes)
    }

    /// Update custom icon for a friend's share
    /// - Parameters:
    ///   - shareCode: Friend's share code
    ///   - symbol: SF Symbol name
    ///   - backgroundHex: Background color hex
    ///   - foregroundHex: Foreground color hex
    func updateFriendIcon(
        shareCode: String,
        symbol: String?,
        backgroundHex: String?,
        foregroundHex: String?
    ) throws {
        try shareRecordRepository.updateIcon(
            shareCode: shareCode,
            symbol: symbol,
            backgroundHex: backgroundHex,
            foregroundHex: foregroundHex
        )
    }
}
