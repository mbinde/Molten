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
    /// v2: Now handles ALL inventory (including those without location)
    private static let migrationCompletedKey = "molten.storageLocation.migrationCompleted.v2"

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

        // 1. Fetch ALL inventory records (not just those with locations!)
        // v2 change: We need StorageLocation records for ALL inventory so receipt import works
        let allInventory = try await inventoryRepository.fetchInventory(matching: nil)

        print("   Found \(allInventory.count) inventory records to check")

        // 2. Cache location definitions for efficiency
        var definitionCache: [String: UUID] = [:]  // locationName -> definitionId

        // 3. Process each inventory record
        for inventory in allInventory {
            stats.processedCount += 1

            // v2: Get location name, defaulting to empty string for inventory without location
            let locationName = inventory.location ?? ""

            do {
                // Check if StorageLocation already exists for this inventory
                let existingLocations = try await storageLocationRepository.fetchLocations(forInventory: inventory.id)
                if !existingLocations.isEmpty {
                    stats.skippedCount += 1
                    continue  // Already migrated
                }

                // Skip if quantity is 0 (no point creating a StorageLocation for empty inventory)
                guard inventory.quantity > 0 else {
                    stats.skippedCount += 1
                    continue
                }

                // Get or create the location definition (only if location name is non-empty)
                let definitionId: UUID?
                if !locationName.isEmpty {
                    if let cachedId = definitionCache[locationName.lowercased()] {
                        definitionId = cachedId
                    } else {
                        definitionId = try await getOrCreateLocationDefinition(name: locationName)
                        if let id = definitionId {
                            definitionCache[locationName.lowercased()] = id
                        }
                    }
                } else {
                    definitionId = nil  // No location definition for inventory without location
                }

                // Create StorageLocation record
                let storageLocation = StorageLocationModel(
                    inventoryId: inventory.id,
                    storageLocationId: definitionId,
                    locationName: locationName,  // Empty string if no location
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
