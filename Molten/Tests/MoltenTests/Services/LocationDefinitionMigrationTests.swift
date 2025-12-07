//
//  LocationDefinitionMigrationTests.swift
//  MoltenTests
//
//  Tests for the one-time location definition migration
//

import Testing
import Foundation
@testable import Molten

@Suite("Location Definition Migration Tests", .serialized)
@MainActor
struct LocationDefinitionMigrationTests {

    // Store AppDependencies at struct level to keep PersistenceController alive
    private let deps = AppDependencies(persistenceController: .createTestController())

    @Test("Migration creates definitions for existing inventory locations")
    func testMigrationCreatesDefinitions() async throws {
        // Setup
        let inventoryRepo = deps.inventoryRepository
        let locationDefRepo = deps.storageLocationDefinitionRepository

        // Create inventory with locations (simulating pre-fix state)
        let testItem = try await deps.catalogService.getGlassItemsLightweight().first!
        let stableId = testItem.stable_id

        // Add inventory directly to repository (bypassing service that would create definitions)
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 5,
            location: "Shelf A"
        ))
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 3,
            location: "Shelf B"
        ))
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "sheet",
            quantity: 2,
            location: "Shelf A"  // Duplicate location
        ))

        // Verify no definitions exist yet
        let beforeDefs = try await locationDefRepo.fetchAll()
        let beforeNames = Set(beforeDefs.map { $0.name })
        #expect(!beforeNames.contains("Shelf A"))
        #expect(!beforeNames.contains("Shelf B"))

        // Run migration
        let migration = LocationDefinitionMigration(
            inventoryRepository: inventoryRepo,
            storageLocationDefinitionRepository: locationDefRepo
        )
        await migration.forceRun()

        // Verify definitions were created
        let afterDefs = try await locationDefRepo.fetchAll()
        let afterNames = Set(afterDefs.map { $0.name })
        #expect(afterNames.contains("Shelf A"))
        #expect(afterNames.contains("Shelf B"))
    }

    @Test("Migration skips empty and nil locations")
    func testMigrationSkipsEmptyLocations() async throws {
        // Setup
        let inventoryRepo = deps.inventoryRepository
        let locationDefRepo = deps.storageLocationDefinitionRepository

        let testItem = try await deps.catalogService.getGlassItemsLightweight().first!
        let stableId = testItem.stable_id

        // Add inventory with nil location
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 5,
            location: nil
        ))
        // Add inventory with empty location
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 3,
            location: ""
        ))
        // Add one with a real location
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 2,
            location: "Valid Location"
        ))

        // Run migration
        let migration = LocationDefinitionMigration(
            inventoryRepository: inventoryRepo,
            storageLocationDefinitionRepository: locationDefRepo
        )
        await migration.forceRun()

        // Verify only valid location was created
        let afterDefs = try await locationDefRepo.fetchAll()
        let afterNames = Set(afterDefs.map { $0.name })
        #expect(afterNames.contains("Valid Location"))
        #expect(!afterNames.contains(""))
    }

    @Test("Migration does not duplicate existing definitions")
    func testMigrationDoesNotDuplicateDefinitions() async throws {
        // Setup
        let inventoryRepo = deps.inventoryRepository
        let locationDefRepo = deps.storageLocationDefinitionRepository

        let testItem = try await deps.catalogService.getGlassItemsLightweight().first!
        let stableId = testItem.stable_id

        // Pre-create a definition
        let existingDef = StorageLocationDefinitionModel(name: "Existing Location")
        _ = try await locationDefRepo.create(existingDef)

        // Add inventory with that location
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 5,
            location: "Existing Location"
        ))

        // Run migration
        let migration = LocationDefinitionMigration(
            inventoryRepository: inventoryRepo,
            storageLocationDefinitionRepository: locationDefRepo
        )
        await migration.forceRun()

        // Verify only one definition exists (not duplicated)
        let allDefs = try await locationDefRepo.fetchAll()
        let matchingDefs = allDefs.filter { $0.name == "Existing Location" }
        #expect(matchingDefs.count == 1)
    }

    @Test("Migration only runs once")
    func testMigrationOnlyRunsOnce() async throws {
        // Setup
        let inventoryRepo = deps.inventoryRepository
        let locationDefRepo = deps.storageLocationDefinitionRepository

        let testItem = try await deps.catalogService.getGlassItemsLightweight().first!
        let stableId = testItem.stable_id

        // Run migration first time with no inventory
        let migration = LocationDefinitionMigration(
            inventoryRepository: inventoryRepo,
            storageLocationDefinitionRepository: locationDefRepo
        )
        await migration.forceRun()

        // Now add inventory AFTER migration ran
        _ = try await inventoryRepo.createInventory(InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 5,
            location: "New Location"
        ))

        // Try to run migration again (should skip because already ran)
        await migration.runIfNeeded()

        // Verify definition was NOT created (migration was skipped)
        let allDefs = try await locationDefRepo.fetchAll()
        let matchingDefs = allDefs.filter { $0.name == "New Location" }
        #expect(matchingDefs.isEmpty)
    }
}
