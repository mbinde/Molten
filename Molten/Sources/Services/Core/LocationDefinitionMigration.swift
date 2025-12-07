//
//  LocationDefinitionMigration.swift
//  Molten
//
//  Migration to create StorageLocationDefinition entities for existing
//  inventory locations that were created before the autocomplete fix.
//
//  Background: Prior to this fix, adding inventory with a location
//  would save the location string on the inventory record but NOT
//  create a StorageLocationDefinition entry. This meant locations
//  would not appear in autocomplete suggestions.
//
//  IDEMPOTENCY: This migration is safe to run multiple times. It fetches
//  all inventory locations, compares against existing definitions, and
//  only creates definitions for locations that don't already exist.
//  If interrupted mid-migration, the next run will pick up where it
//  left off without creating duplicates.
//
//  CURRENT BEHAVIOR: Runs on every app launch until it finds nothing
//  to migrate, then marks itself complete. This ensures any code paths
//  still using the old system (bypassing the service layer) will
//  eventually have their locations backfilled.
//
//  TODO (future update): Once we're confident all code paths create
//  definitions properly, we can simplify to just check the completion
//  flag without re-running the migration each time.
//

import Foundation
import OSLog

/// Migration service to backfill StorageLocationDefinition entities
/// from existing inventory location strings.
///
/// This migration is idempotent - safe to run multiple times. It will
/// only create definitions for locations that don't already exist.
final class LocationDefinitionMigration: Sendable {

    private let inventoryRepository: InventoryRepository
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    private let logger = Logger(subsystem: "com.motleywoods.molten", category: "migration")

    /// UserDefaults key to track if migration has been performed
    private static let migrationCompletedKey = "LocationDefinitionMigration_v1_completed"

    init(
        inventoryRepository: InventoryRepository,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    ) {
        self.inventoryRepository = inventoryRepository
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
    }

    /// Check if migration has already been performed
    var hasRunMigration: Bool {
        UserDefaults.standard.bool(forKey: Self.migrationCompletedKey)
    }

    /// Run migration if not already completed
    ///
    /// Runs on every launch until there's nothing left to migrate,
    /// then marks itself complete. This is idempotent - safe to call
    /// multiple times without creating duplicates.
    func runIfNeeded() async {
        guard !hasRunMigration else {
            logger.debug("Location definition migration already completed, skipping")
            return
        }

        logger.info("Starting location definition migration...")

        do {
            let createdCount = try await performMigration()

            if createdCount == 0 {
                // Nothing needed to be created - mark migration as complete
                UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
                logger.info("Location definition migration completed - no missing definitions found")
            } else {
                // Created some definitions - don't mark complete yet
                // Run again next launch to catch any stragglers
                logger.info("Location definition migration created \(createdCount) definitions, will check again next launch")
            }
        } catch {
            // Log error but don't mark as completed - allow retry on next launch
            logger.error("Location definition migration failed: \(error.localizedDescription)")
        }
    }

    /// Perform the actual migration
    /// - Returns: Number of definitions created (0 means nothing was missing)
    private func performMigration() async throws -> Int {
        // 1. Get all inventory records
        let allInventory = try await inventoryRepository.fetchInventory(matching: nil)

        // 2. Extract unique non-empty location names
        let locationNames = Set(
            allInventory
                .compactMap { $0.location }
                .filter { !$0.isEmpty }
        )

        guard !locationNames.isEmpty else {
            logger.info("No inventory locations found, nothing to migrate")
            return 0
        }

        logger.info("Found \(locationNames.count) unique location names in inventory")

        // 3. Get existing location definitions
        let existingDefinitions = try await storageLocationDefinitionRepository.fetchAll()
        let existingNames = Set(existingDefinitions.map { $0.name })

        // 4. Find locations that need definitions created
        let missingLocations = locationNames.subtracting(existingNames)

        guard !missingLocations.isEmpty else {
            logger.info("All inventory locations already have definitions, nothing to migrate")
            return 0
        }

        logger.info("Creating \(missingLocations.count) missing location definitions")

        // 5. Create missing definitions
        var created = 0
        for locationName in missingLocations {
            do {
                let newDefinition = StorageLocationDefinitionModel(name: locationName)
                _ = try await storageLocationDefinitionRepository.create(newDefinition)
                created += 1
            } catch {
                // Log but continue - don't let one failure stop the whole migration
                logger.warning("Failed to create definition for '\(locationName)': \(error.localizedDescription)")
            }
        }

        logger.info("Created \(created) location definitions")
        return created
    }

    /// Force re-run the migration (for testing/debugging)
    /// Clears the completion flag and runs again
    func forceRun() async {
        UserDefaults.standard.removeObject(forKey: Self.migrationCompletedKey)
        await runIfNeeded()
    }
}
