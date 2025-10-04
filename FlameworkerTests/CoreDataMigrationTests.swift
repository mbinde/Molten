//
//  CoreDataMigrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Migration Tests")
struct CoreDataMigrationTests {
    
    @Test("Should migrate units from InventoryItem to CatalogItem on startup")
    func testUnitsMigrationFromInventoryToCatalog() async throws {
        let context = PersistenceController.preview.container.viewContext
        
        // Reset migration status for clean test
        CoreDataMigrationService.shared.resetMigrationStatusForTesting()
        
        // Simulate old data: InventoryItem with units, CatalogItem without units
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "OLD-CATALOG-001"
        catalogItem.code = "OLD-CATALOG-001"
        catalogItem.name = "Old Glass Rod"
        catalogItem.units = 0 // Simulate uninitialized state
        
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.id = "OLD-INVENTORY-001"
        inventoryItem.catalog_code = "OLD-CATALOG-001"
        inventoryItem.count = 25.0
        inventoryItem.type = InventoryItemType.sell.rawValue
        
        try context.save()
        
        // Simulate the migration process
        let migrationService = CoreDataMigrationService.shared
        let migrationNeeded = try await migrationService.checkIfUnitsMigrationNeeded(in: context)
        
        #expect(migrationNeeded == true, "Should detect that migration is needed for legacy data")
        
        // Perform the migration
        try await migrationService.migrateUnitsFromInventoryToCatalog(in: context)
        
        // Verify migration completed successfully
        let postMigrationNeeded = try await migrationService.checkIfUnitsMigrationNeeded(in: context)
        #expect(postMigrationNeeded == false, "Migration should be complete")
        
        // Verify data integrity after migration
        #expect(catalogItem.units == InventoryUnits.rods.rawValue, "Catalog item should have default units")
        #expect(inventoryItem.unitsKind == .rods, "Should still access units through catalog relationship")
    }
    
    @Test("Should handle migration when catalog item doesn't exist")
    func testUnitsMigrationWithMissingCatalogItem() async throws {
        let context = PersistenceController.preview.container.viewContext
        
        // Reset migration status for clean test
        CoreDataMigrationService.shared.resetMigrationStatusForTesting()
        
        // Create inventory item with catalog_code that doesn't match any catalog item
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.id = "ORPHANED-INVENTORY"
        inventoryItem.catalog_code = "MISSING-CATALOG"
        inventoryItem.count = 15.0
        inventoryItem.type = InventoryItemType.buy.rawValue
        
        try context.save()
        
        let migrationService = CoreDataMigrationService.shared
        
        // Should handle gracefully without crashing
        try await migrationService.migrateUnitsFromInventoryToCatalog(in: context)
        
        // Should use fallback units
        #expect(inventoryItem.unitsKind == .rods, "Should fallback to rods for orphaned items")
    }
    
    @Test("Should skip migration if already completed")
    func testSkipMigrationIfAlreadyCompleted() async throws {
        let context = PersistenceController.preview.container.viewContext
        
        let migrationService = CoreDataMigrationService.shared
        
        // Mark migration as already completed
        migrationService.markUnitsMigrationCompleted()
        
        let migrationNeeded = try await migrationService.checkIfUnitsMigrationNeeded(in: context)
        #expect(migrationNeeded == false, "Should skip migration if already completed")
        
        // Clean up
        migrationService.resetMigrationStatusForTesting()
    }
    
    @Test("Should report migration progress accurately")
    func testMigrationProgressReporting() async throws {
        let context = PersistenceController.preview.container.viewContext
        
        // Reset migration status for clean test
        CoreDataMigrationService.shared.resetMigrationStatusForTesting()
        
        // Create multiple catalog items to test progress reporting
        let itemCount = 5
        for i in 1...itemCount {
            let catalogItem = CatalogItem(context: context)
            catalogItem.id = "PROGRESS-TEST-\(i)"
            catalogItem.code = "PROGRESS-TEST-\(i)"
            catalogItem.name = "Progress Test Item \(i)"
            catalogItem.units = (i % 2 == 0) ? 0 : InventoryUnits.rods.rawValue // Mix of initialized and uninitialized
        }
        
        try context.save()
        
        let migrationService = CoreDataMigrationService.shared
        var progressUpdates: [MigrationProgress] = []
        
        // Set up progress callback to capture updates
        await migrationService.setProgressCallback { progress in
            progressUpdates.append(progress)
        }
        
        // Perform migration with progress reporting
        try await migrationService.migrateUnitsFromInventoryToCatalog(in: context)
        
        // Verify progress updates were received
        #expect(!progressUpdates.isEmpty, "Should have received progress updates")
        
        // Verify progress phases are represented
        let phases = Set(progressUpdates.map { $0.phase })
        #expect(phases.contains(.catalogMigration), "Should include catalog migration phase")
        #expect(phases.contains(.complete), "Should include completion phase")
        
        // Verify final progress shows completion
        let finalProgress = progressUpdates.last
        #expect(finalProgress?.phase == .complete, "Final progress should be complete")
        #expect(finalProgress?.percentComplete == 100.0, "Final progress should be 100%")
        
        // Clean up
        await migrationService.clearProgressCallback()
    }
}