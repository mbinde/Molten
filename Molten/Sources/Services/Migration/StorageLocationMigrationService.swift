//
//  StorageLocationMigrationService.swift
//  Molten
//
//  One-time migration service to convert legacy Inventory.location strings
//  to proper StorageLocation records pointing to StorageLocationDefinition entities.
//

import Foundation

/// Service for migrating legacy Inventory.location data to the new StorageLocation architecture.
///
/// The migration:
/// 1. Finds all Inventory records with a non-nil location string
/// 2. For each, creates a StorageLocation record linking to the appropriate StorageLocationDefinition
/// 3. Preserves original date_added, quantity, and containerCount
/// 4. Marks migration complete to avoid re-running
///
/// This migration is idempotent - it checks for existing StorageLocation records before creating new ones.
actor StorageLocationMigrationService {

    // MARK: - Migration Key

    /// UserDefaults key to track migration completion
    private static let migrationCompletedKey = "molten.storageLocation.migrationCompleted"

    // MARK: - Dependencies

    private let inventoryRepository: InventoryRepository
    private let storageLocationRepository: StorageLocationRepository
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    // MARK: - Initialization

    init(
        inventoryRepository: InventoryRepository,
        storageLocationRepository: StorageLocationRepository,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    ) {
        self.inventoryRepository = inventoryRepository
        self.storageLocationRepository = storageLocationRepository
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
    }

    // MARK: - Migration

    /// Check if migration has already been completed
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: Self.migrationCompletedKey)
    }

    /// Run the migration if not already completed.
    /// This should be called early in app startup.
    func runMigrationIfNeeded() async {
        guard !isMigrationCompleted else {
            print("✅ StorageLocation migration already completed, skipping")
            return
        }

        print("🔄 Starting StorageLocation migration...")

        do {
            let stats = try await performMigration()

            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)

            print("✅ StorageLocation migration completed:")
            print("   - Processed \(stats.processedCount) inventory records")
            print("   - Created \(stats.createdCount) StorageLocation records")
            print("   - Skipped \(stats.skippedCount) (already migrated)")
            print("   - Errors: \(stats.errorCount)")
        } catch {
            print("❌ StorageLocation migration failed: \(error)")
            // Don't mark as complete so we can retry next launch
        }
    }

    /// Force run the migration (for debugging/manual trigger)
    func forceRunMigration() async {
        // Reset the completion flag
        UserDefaults.standard.removeObject(forKey: Self.migrationCompletedKey)
        await runMigrationIfNeeded()
    }

    // MARK: - Private Migration Logic

    private struct MigrationStats {
        var processedCount = 0
        var createdCount = 0
        var skippedCount = 0
        var errorCount = 0
    }

    private func performMigration() async throws -> MigrationStats {
        var stats = MigrationStats()

        // 1. Fetch all inventory records with non-nil location
        let allInventory = try await inventoryRepository.fetchInventory(matching: nil)
        let inventoryWithLocation = allInventory.filter { $0.location != nil && !$0.location!.isEmpty }

        print("   Found \(inventoryWithLocation.count) inventory records with locations to migrate")

        // 2. Cache location definitions for efficiency
        var definitionCache: [String: UUID] = [:]  // locationName -> definitionId

        // 3. Process each inventory record
        for inventory in inventoryWithLocation {
            stats.processedCount += 1

            guard let locationName = inventory.location, !locationName.isEmpty else {
                continue
            }

            do {
                // Check if StorageLocation already exists for this inventory
                let existingLocations = try await storageLocationRepository.fetchLocations(forInventory: inventory.id)
                if !existingLocations.isEmpty {
                    stats.skippedCount += 1
                    continue  // Already migrated
                }

                // Get or create the location definition
                let definitionId: UUID?
                if let cachedId = definitionCache[locationName.lowercased()] {
                    definitionId = cachedId
                } else {
                    definitionId = try await getOrCreateLocationDefinition(name: locationName)
                    if let id = definitionId {
                        definitionCache[locationName.lowercased()] = id
                    }
                }

                // Create StorageLocation record
                let storageLocation = StorageLocationModel(
                    inventoryId: inventory.id,
                    storageLocationId: definitionId,
                    locationName: locationName,  // Cache the name for backward compatibility
                    quantity: inventory.quantity,
                    containerCount: inventory.containerCount,
                    dateAdded: inventory.date_added,  // Preserve original date
                    dateModified: inventory.date_modified,
                    isTransfer: false  // Legacy data is not a transfer
                )

                _ = try await storageLocationRepository.createLocation(storageLocation)
                stats.createdCount += 1

            } catch {
                print("   ⚠️ Failed to migrate inventory \(inventory.id): \(error)")
                stats.errorCount += 1
                // Continue with other records
            }
        }

        return stats
    }

    /// Get existing or create new StorageLocationDefinition for the given name
    private func getOrCreateLocationDefinition(name: String) async throws -> UUID? {
        // Check if definition already exists (case-insensitive)
        if let existing = try await storageLocationDefinitionRepository.fetch(byName: name) {
            return existing.id
        }

        // Create new definition
        let newDefinition = StorageLocationDefinitionModel(name: name)
        let created = try await storageLocationDefinitionRepository.create(newDefinition)
        return created.id
    }
}
