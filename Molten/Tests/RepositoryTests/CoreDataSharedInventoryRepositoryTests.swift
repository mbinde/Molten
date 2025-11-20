//
//  CoreDataSharedInventoryRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataSharedInventoryRepository - manages normalized friend inventory cache
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data SharedInventory Repository Tests")
@MainActor
struct CoreDataSharedInventoryRepositoryTests {

    // MARK: - Save Tests

    @Test("Should save inventory snapshot")
    func testSaveInventorySnapshot() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create catalog item first (required for getSnapshot to work)
        let glassItem = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem)

        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: "Shelf A"
            )
        ]

        // Test
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Verify
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        #expect(snapshot.count == 1)
        #expect(snapshot[0].stableId == "test-123")
        #expect(snapshot[0].quantity == 5.0)
        #expect(snapshot[0].unit == "rod")
        #expect(snapshot[0].location == "Shelf A")
    }

    @Test("Should save inventory with tags")
    func testSaveInventoryWithTags() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create catalog item first (required for getSnapshot to work)
        let glassItem = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem)

        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil,
                tags: ["transparent", "coe90"]
            )
        ]

        // Test
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Verify
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        #expect(snapshot.count == 1)
        #expect(snapshot[0].tags != nil)
        #expect(snapshot[0].tags?.contains("transparent") == true)
        #expect(snapshot[0].tags?.contains("coe90") == true)
    }

    @Test("Should replace existing snapshot when saving")
    func testReplaceExistingSnapshot() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create catalog items first (required for getSnapshot to work)
        let glassItem1 = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem1)

        let glassItem2 = GlassItemModel(
            stable_id: "test-456",
            name: "Clear Tube",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem2)

        let items1 = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]

        let items2 = [
            InventoryItemSnapshot(
                stableId: "test-456",
                manufacturer: "bullseye",
                sku: "002",
                quantity: 10.0,
                unit: "tube",
                location: "Shelf B"
            )
        ]

        // Test
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items1)
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items2)

        // Verify - should only have items2
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        #expect(snapshot.count == 1)
        #expect(snapshot[0].stableId == "test-456")
        #expect(snapshot[0].quantity == 10.0)
    }

    @Test("Should save multiple snapshots for different share codes")
    func testSaveMultipleSnapshots() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create catalog items first (required for getSnapshot to work)
        let glassItem1 = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem1)

        let glassItem2 = GlassItemModel(
            stable_id: "test-456",
            name: "Clear Tube",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem2)

        let items1 = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]

        let items2 = [
            InventoryItemSnapshot(
                stableId: "test-456",
                manufacturer: "bullseye",
                sku: "002",
                quantity: 10.0,
                unit: "tube",
                location: nil
            )
        ]

        // Test
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items1)
        try sharedRepo.saveSnapshot(shareCode: "DEF456", items: items2)

        // Verify
        let snapshot1 = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        let snapshot2 = try await sharedRepo.getSnapshot(shareCode: "DEF456")

        #expect(snapshot1.count == 1)
        #expect(snapshot2.count == 1)
        #expect(snapshot1[0].stableId == "test-123")
        #expect(snapshot2[0].stableId == "test-456")
    }

    // MARK: - Fetch Tests

    @Test("Should return empty array for non-existent share code")
    func testGetNonExistentSnapshot() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, _) = try await createTestRepositories(controller: controller)

        // Test
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "NOTFOUND")

        // Verify
        #expect(snapshot.isEmpty)
    }

    @Test("Should lookup catalog data when retrieving snapshot")
    func testCatalogLookupOnRetrieval() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create glass item in catalog
        let glassItem = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem)

        // Save snapshot (only stable_id stored)
        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",  // This gets looked up from catalog
                sku: "001",                // This gets looked up from catalog
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Test - retrieve should lookup manufacturer/SKU from catalog
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")

        // Verify
        #expect(snapshot.count == 1)
        #expect(snapshot[0].manufacturer == "bullseye")
        #expect(snapshot[0].sku == "001")
    }

    @Test("Should skip items not in catalog")
    func testSkipMissingCatalogItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Only create one glass item
        let glassItem = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem)

        // Save snapshot with two items (one not in catalog)
        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            ),
            InventoryItemSnapshot(
                stableId: "missing-999",
                manufacturer: "test",
                sku: "999",
                quantity: 10.0,
                unit: "tube",
                location: nil
            )
        ]
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Test
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")

        // Verify - should only return item that exists in catalog
        #expect(snapshot.count == 1)
        #expect(snapshot[0].stableId == "test-123")
    }

    // MARK: - Delete Tests

    @Test("Should delete inventory snapshot")
    func testDeleteSnapshot() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, _) = try await createTestRepositories(controller: controller)

        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Test
        try sharedRepo.deleteSnapshot(shareCode: "ABC123")

        // Verify
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        #expect(snapshot.isEmpty)
    }

    @Test("Should delete snapshot and associated tags")
    func testDeleteSnapshotWithTags() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, _) = try await createTestRepositories(controller: controller)

        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil,
                tags: ["transparent", "coe90"]
            )
        ]
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Test
        try sharedRepo.deleteSnapshot(shareCode: "ABC123")

        // Verify
        let snapshot = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        #expect(snapshot.isEmpty)
    }

    @Test("Should not delete other snapshots")
    func testDeleteOnlySpecificSnapshot() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create catalog items first (required for getSnapshot to work)
        let glassItem1 = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem1)

        let glassItem2 = GlassItemModel(
            stable_id: "test-456",
            name: "Clear Tube",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(glassItem2)

        let items1 = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]

        let items2 = [
            InventoryItemSnapshot(
                stableId: "test-456",
                manufacturer: "bullseye",
                sku: "002",
                quantity: 10.0,
                unit: "tube",
                location: nil
            )
        ]

        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items1)
        try sharedRepo.saveSnapshot(shareCode: "DEF456", items: items2)

        // Test
        try sharedRepo.deleteSnapshot(shareCode: "ABC123")

        // Verify
        let snapshot1 = try await sharedRepo.getSnapshot(shareCode: "ABC123")
        let snapshot2 = try await sharedRepo.getSnapshot(shareCode: "DEF456")

        #expect(snapshot1.isEmpty)
        #expect(snapshot2.count == 1)
    }

    // MARK: - Tag Query Tests

    @Test("Should find items with specific tag")
    func testGetItemsWithTag() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create glass items
        let item1 = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "test-456",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(item1)
        _ = try await glassRepo.createItem(item2)

        // Save snapshots with tags
        let items = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil,
                tags: ["transparent", "coe90"]
            ),
            InventoryItemSnapshot(
                stableId: "test-456",
                manufacturer: "bullseye",
                sku: "002",
                quantity: 10.0,
                unit: "rod",
                location: nil,
                tags: ["opaque", "coe90"]
            )
        ]
        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items)

        // Test
        let transparentItems = try await sharedRepo.getItemsWithTag(tag: "transparent")
        let coe90Items = try await sharedRepo.getItemsWithTag(tag: "coe90")

        // Verify
        #expect(transparentItems.count == 1)
        #expect(transparentItems[0].stableId == "test-123")

        #expect(coe90Items.count == 2)
    }

    @Test("Should find items across multiple share codes")
    func testGetItemsWithTagAcrossShares() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let (sharedRepo, glassRepo) = try await createTestRepositories(controller: controller)

        // Create glass items
        let item1 = GlassItemModel(
            stable_id: "test-123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "test-456",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await glassRepo.createItem(item1)
        _ = try await glassRepo.createItem(item2)

        // Save to different share codes
        let items1 = [
            InventoryItemSnapshot(
                stableId: "test-123",
                manufacturer: "bullseye",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil,
                tags: ["transparent"]
            )
        ]

        let items2 = [
            InventoryItemSnapshot(
                stableId: "test-456",
                manufacturer: "bullseye",
                sku: "002",
                quantity: 10.0,
                unit: "rod",
                location: nil,
                tags: ["transparent"]
            )
        ]

        try sharedRepo.saveSnapshot(shareCode: "ABC123", items: items1)
        try sharedRepo.saveSnapshot(shareCode: "DEF456", items: items2)

        // Test
        let transparentItems = try await sharedRepo.getItemsWithTag(tag: "transparent")

        // Verify - should find items from both shares
        #expect(transparentItems.count == 2)
    }

    // MARK: - Helper Methods

    private func createTestRepositories(controller: PersistenceController) async throws -> (CoreDataSharedInventoryRepository, GlassItemRepository) {
        // Create test SQLite repository (now used for both production and tests)
        guard let bundlePath = Bundle.main.path(forResource: "catalog", ofType: "sqlite") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Catalog database not found"])
        }
        let testDbManager = TestCatalogDatabaseManager(databasePath: bundlePath)
        try testDbManager.initialize()

        let glassRepo = SQLiteGlassItemRepository(databaseManager: testDbManager)
        let sharedRepo = CoreDataSharedInventoryRepository(
            context: controller.container.viewContext,
            catalogRepository: glassRepo
        )
        return (sharedRepo, glassRepo)
    }
}
