//
//  InventorySharingService.swift
//  Molten
//
//  High-level orchestration service for inventory sharing
//  Coordinates share code generation, snapshot creation, signing, and API calls
//

import Foundation

/// High-level service for inventory sharing operations
@MainActor
open class InventorySharingService {

    // MARK: - Properties

    private let apiClient: InventorySharingAPIClient
    private let keyPairManager: KeyPairManager
    private let shareCodeGenerator: ShareCodeGenerator
    private let snapshot: InventorySnapshot
    private let maxConflictRetries = 5

    // MARK: - Initialization

    init(
        apiClient: InventorySharingAPIClient = InventorySharingAPIClient(),
        keyPairManager: KeyPairManager = KeyPairManager(),
        shareCodeGenerator: ShareCodeGenerator = ShareCodeGenerator(),
        snapshot: InventorySnapshot = InventorySnapshot()
    ) {
        self.apiClient = apiClient
        self.keyPairManager = keyPairManager
        self.shareCodeGenerator = shareCodeGenerator
        self.snapshot = snapshot
    }

    // MARK: - Share Creation

    /// Create a new share with generated code
    /// - Parameters:
    ///   - items: Inventory items to share
    ///   - metadata: Share owner metadata (display name and notes)
    /// - Returns: Generated share code
    open func createShare(items: [InventoryItemSnapshot], metadata: MyShareMetadata) async throws -> String {
        // Get or generate key pair
        print("🔐 [CREATE] Retrieving/generating key pair...")
        let keyPair = try keyPairManager.getCurrentKeyPair()
        print("🔐 [CREATE] Got key pair - public key: \(keyPair.publicKey.base64EncodedString().prefix(20))...")

        // Try to upload with retries on conflict
        for attempt in 0..<maxConflictRetries {
            // Generate share code
            let shareCode = shareCodeGenerator.generate()
            print("🔐 [CREATE] Generated share code: \(shareCode)")

            // Create snapshot with metadata
            let snapshotData = try snapshot.serialize(
                items: items,
                publicKey: keyPair.publicKey,
                privateKey: keyPair.privateKey,
                metadata: metadata
            )
            print("🔐 [CREATE] Serialized snapshot (\(items.count) items)")

            // Try to upload
            do {
                print("🔐 [CREATE] Uploading to server...")
                try await apiClient.uploadSnapshot(
                    shareCode: shareCode,
                    snapshotData: snapshotData,
                    publicKey: keyPair.publicKey
                )
                print("🔐 [CREATE] Share created successfully with code: \(shareCode)")
                return shareCode
            } catch SharingAPIError.conflict {
                // Code already exists, retry with new code
                if attempt == maxConflictRetries - 1 {
                    throw SharingAPIError.conflict
                }
                continue
            }
        }

        throw SharingAPIError.conflict
    }

    // MARK: - Download

    /// Download friend's inventory by share code
    /// - Parameter shareCode: Share code to download
    /// - Returns: Snapshot result with validity flag
    open func downloadFriendInventory(shareCode: String) async throws -> SnapshotResult {
        // Download from server
        let downloaded = try await apiClient.downloadSnapshot(shareCode: shareCode)

        // Deserialize and verify signature
        var result = try snapshot.deserialize(
            data: downloaded.snapshotData,
            publicKey: downloaded.publicKey
        )

        // Add metadata from download response
        result = SnapshotResult(
            items: result.items,
            timestamp: result.timestamp,
            version: result.version,
            isValid: result.isValid,
            ownerName: downloaded.displayName ?? result.ownerName,
            ownerShareNotes: downloaded.shareNotes ?? result.ownerShareNotes,
            expiresAt: downloaded.expiresAt
        )

        return result
    }

    // MARK: - Update

    /// Update an existing share with new inventory data and/or metadata
    /// - Parameters:
    ///   - shareCode: Share code to update
    ///   - items: New inventory items
    ///   - metadata: Updated share owner metadata (display name and notes)
    open func updateShare(shareCode: String, items: [InventoryItemSnapshot], metadata: MyShareMetadata) async throws {
        // Get current key pair
        let keyPair = try keyPairManager.getCurrentKeyPair()

        // Create new snapshot with metadata
        let snapshotData = try snapshot.serialize(
            items: items,
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey,
            metadata: metadata
        )

        // Create ownership signature (sign the share code with private key)
        let ownershipSignature = try keyPairManager.sign(
            data: shareCode.data(using: .utf8)!,
            privateKey: keyPair.privateKey
        )

        // Update on server
        try await apiClient.updateSnapshot(
            shareCode: shareCode,
            snapshotData: snapshotData,
            publicKey: keyPair.publicKey,
            ownershipSignature: ownershipSignature
        )
    }

    // MARK: - Delete

    /// Delete a share by code
    /// - Parameter shareCode: Share code to delete
    open func deleteShare(shareCode: String) async throws {
        print("🔐 [DELETE] Starting deletion for share code: \(shareCode)")

        // Get current key pair
        print("🔐 [DELETE] Retrieving current key pair...")
        let keyPair = try keyPairManager.getCurrentKeyPair()
        print("🔐 [DELETE] Got key pair - public key: \(keyPair.publicKey.base64EncodedString().prefix(20))...")

        // Create ownership signature (sign the share code with private key)
        print("🔐 [DELETE] Signing share code with private key...")
        let ownershipSignature = try keyPairManager.sign(
            data: shareCode.data(using: .utf8)!,
            privateKey: keyPair.privateKey
        )
        print("🔐 [DELETE] Created signature: \(ownershipSignature.base64EncodedString().prefix(20))...")

        // Delete from server
        print("🔐 [DELETE] Sending DELETE request to server...")
        do {
            try await apiClient.deleteShare(shareCode: shareCode, ownershipSignature: ownershipSignature)
            print("🔐 [DELETE] Server deletion successful")
        } catch {
            print("🔐 [DELETE] Server deletion failed: \(error)")
            print("🔐 [DELETE] Error type: \(type(of: error))")
            if let apiError = error as? SharingAPIError {
                print("🔐 [DELETE] SharingAPIError: \(apiError)")
            }
            throw error
        }
    }
}
