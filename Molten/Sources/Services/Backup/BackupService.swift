//
//  BackupService.swift
//  Molten
//
//  High-level service for automatic inventory backups
//  Coordinates backup key management, checksum computation, and API calls
//
//  Backup triggers:
//  1. Primary: On app open, if 20+ hours since last backup AND checksum differs
//  2. Opportunistic: On app background (with UIApplication.beginBackgroundTask)
//

import Foundation
import CryptoKit

/// Backup types supported by the service
enum BackupType: String, CaseIterable {
    case inventory
    case tags
}

/// Result of a backup operation
struct BackupResult {
    let type: BackupType
    let skipped: Bool
    let timestamp: String?
    let checksum: String
}

/// High-level service for automatic inventory backup operations
@MainActor
open class BackupService {

    // MARK: - Constants

    /// Minimum hours between backups to consider backing up again
    static let minimumBackupIntervalHours: Double = 20.0

    /// Keychain identifier for backup key's private key
    private static let backupKeyIdentifier = "com.molten.backup.key"

    // MARK: - Properties

    private let apiClient: BackupAPIClient
    private let keyPairManager: KeyPairManager
    private let keyGenerator: BackupKeyGenerator
    private let preferences: BackupPreferences
    private let inventoryRepository: InventoryRepository
    private let maxConflictRetries = 5

    // MARK: - Initialization

    init(
        apiClient: BackupAPIClient = BackupAPIClient(),
        keyPairManager: KeyPairManager = KeyPairManager(),
        keyGenerator: BackupKeyGenerator = BackupKeyGenerator(),
        preferences: BackupPreferences = BackupPreferences(),
        inventoryRepository: InventoryRepository
    ) {
        self.apiClient = apiClient
        self.keyPairManager = keyPairManager
        self.keyGenerator = keyGenerator
        self.preferences = preferences
        self.inventoryRepository = inventoryRepository
    }

    // MARK: - Setup

    /// Check if backups are set up
    var isSetUp: Bool {
        preferences.backupKey != nil && preferences.isEnabled
    }

    /// Get the current backup key (for display to user)
    var backupKey: String? {
        preferences.backupKey
    }

    /// Enable backups by generating and registering a new backup key
    /// - Returns: The generated backup key
    /// - Throws: BackupAPIError on failure
    open func enableBackups() async throws -> String {
        // Generate key pair for ownership signing
        let keyPair = try keyPairManager.generateAndStoreKeyPair(identifier: Self.backupKeyIdentifier)

        // Try to register with retries on conflict
        for _ in 0..<maxConflictRetries {
            // Generate backup key
            let backupKey = keyGenerator.generate()

            // Try to register
            do {
                try await apiClient.registerBackupKey(backupKey, publicKey: keyPair.publicKey)

                // Success - save preferences
                preferences.backupKey = backupKey
                preferences.isEnabled = true
                preferences.lastBackupTimestamp = nil
                preferences.lastInventoryChecksum = nil
                preferences.lastTagsChecksum = nil

                return backupKey
            } catch BackupAPIError.conflict {
                // Key already exists, retry with new key
                continue
            }
        }

        throw BackupAPIError.conflict
    }

    /// Disable backups and clear stored data
    func disableBackups() {
        preferences.reset()
        try? keyPairManager.deletePrivateKey(identifier: Self.backupKeyIdentifier)
    }

    /// Reroll the backup key (generate new key, keep same keypair)
    /// - Returns: The new backup key
    open func rerollBackupKey() async throws -> String {
        guard preferences.isEnabled else {
            throw BackupAPIError.unauthorized
        }

        // Get existing key pair
        let keyPair: KeyPair
        do {
            let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.backupKeyIdentifier)
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            keyPair = KeyPair(
                publicKey: signingKey.publicKey.rawRepresentation,
                privateKey: privateKey
            )
        } catch {
            // If key pair doesn't exist, regenerate
            throw BackupAPIError.unauthorized
        }

        // Try to register new key with retries on conflict
        for _ in 0..<maxConflictRetries {
            let newBackupKey = keyGenerator.generate()

            do {
                try await apiClient.registerBackupKey(newBackupKey, publicKey: keyPair.publicKey)

                // Success - update preferences
                preferences.backupKey = newBackupKey
                preferences.lastBackupTimestamp = nil
                preferences.lastInventoryChecksum = nil
                preferences.lastTagsChecksum = nil

                return newBackupKey
            } catch BackupAPIError.conflict {
                continue
            }
        }

        throw BackupAPIError.conflict
    }

    // MARK: - Backup Triggers

    /// Check if backup should run on app open
    /// - Returns: true if backup should be attempted
    func shouldBackupOnAppOpen() -> Bool {
        guard isSetUp else { return false }

        // Check if enough time has passed
        guard let hours = preferences.hoursSinceLastBackup else {
            // Never backed up - should backup
            return true
        }

        return hours >= Self.minimumBackupIntervalHours
    }

    /// Perform backup on app open if needed
    /// - Returns: Array of backup results, or empty if skipped
    func backupOnAppOpenIfNeeded() async throws -> [BackupResult] {
        guard shouldBackupOnAppOpen() else {
            return []
        }

        return try await performBackup()
    }

    /// Perform opportunistic backup on app background
    /// - Returns: Array of backup results, or empty if skipped
    func backupOnBackground() async throws -> [BackupResult] {
        guard isSetUp else { return [] }

        return try await performBackup()
    }

    // MARK: - Backup Operations

    /// Perform backup of inventory
    /// - Returns: Array of backup results
    func performBackup() async throws -> [BackupResult] {
        guard let backupKey = preferences.backupKey else {
            throw BackupAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.backupKeyIdentifier)

        // Create ownership signature (sign the backup key)
        let ownershipSignature = try keyPairManager.sign(
            data: backupKey.data(using: .utf8)!,
            privateKey: privateKey
        )

        var results: [BackupResult] = []

        // Backup inventory
        let inventoryResult = try await backupInventory(
            backupKey: backupKey,
            ownershipSignature: ownershipSignature
        )
        results.append(inventoryResult)

        // Update last backup timestamp if any backup was performed
        if results.contains(where: { !$0.skipped }) {
            preferences.lastBackupTimestamp = Date()
        }

        return results
    }

    // MARK: - Private Backup Methods

    private func backupInventory(backupKey: String, ownershipSignature: Data) async throws -> BackupResult {
        // Fetch all inventory (nil predicate means all records)
        let inventoryRecords = try await inventoryRepository.fetchInventory(matching: nil)

        // Create inventory snapshot data (sorted for consistent checksum)
        let sortedRecords = inventoryRecords.sorted { r1, r2 in
            if r1.item_stable_id != r2.item_stable_id {
                return r1.item_stable_id < r2.item_stable_id
            }
            return (r1.location ?? "") < (r2.location ?? "")
        }

        // Serialize to JSON
        let payload = InventoryBackupPayload(
            version: "1.0",
            timestamp: Date(),
            records: sortedRecords.map { InventoryRecordBackup(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys  // Consistent key ordering for checksum
        let jsonData = try encoder.encode(payload)

        // Compute checksum
        let checksum = computeChecksum(jsonData)

        // Check if checksum changed
        if checksum == preferences.lastInventoryChecksum {
            return BackupResult(type: .inventory, skipped: true, timestamp: nil, checksum: checksum)
        }

        // Upload backup
        let base64Data = jsonData.base64EncodedString()
        let result = try await apiClient.uploadBackup(
            backupKey: backupKey,
            type: BackupType.inventory.rawValue,
            data: base64Data,
            checksum: checksum,
            ownershipSignature: ownershipSignature
        )

        // Update stored checksum
        if !result.skipped {
            preferences.lastInventoryChecksum = checksum
        }

        return BackupResult(type: .inventory, skipped: result.skipped, timestamp: result.timestamp, checksum: checksum)
    }

    // MARK: - Restore Operations

    /// Download and restore inventory backup
    /// - Returns: Number of records restored
    open func restoreInventory() async throws -> Int {
        guard let backupKey = preferences.backupKey else {
            throw BackupAPIError.unauthorized
        }

        let result = try await apiClient.downloadBackup(backupKey: backupKey, type: BackupType.inventory.rawValue)

        // Decode backup data
        guard let jsonData = Data(base64Encoded: result.data) else {
            throw BackupAPIError.invalidData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(InventoryBackupPayload.self, from: jsonData)

        // Restore records
        // Note: This is a simplified implementation. In practice, you'd want to
        // handle merging with existing data, conflicts, etc.
        for record in payload.records {
            let model = record.toModel()
            _ = try await inventoryRepository.createInventory(model)
        }

        return payload.records.count
    }

    // MARK: - Helpers

    private func computeChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Backup Payload Types

private struct InventoryBackupPayload: Codable {
    let version: String
    let timestamp: Date
    let records: [InventoryRecordBackup]
}

private struct InventoryRecordBackup: Codable {
    let itemStableId: String
    let type: String
    let subtype: String?
    let subsubtype: String?
    let quantity: Double
    let containerCount: Double?
    let location: String?
    let dimensions: [String: Double]?

    init(from model: InventoryModel) {
        self.itemStableId = model.item_stable_id
        self.type = model.type
        self.subtype = model.subtype
        self.subsubtype = model.subsubtype
        self.quantity = model.quantity
        self.containerCount = model.containerCount
        self.location = model.location
        self.dimensions = model.dimensions
    }

    func toModel() -> InventoryModel {
        InventoryModel(
            id: UUID(),
            item_stable_id: itemStableId,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dimensions: dimensions,
            quantity: quantity,
            containerCount: containerCount,
            location: location
        )
    }
}
