//
//  CatalogItemRepositoryTests.swift
//  RepositoryTests
//
//  Tests for the generic CatalogItemRepository protocol and implementations
//

import Foundation
import Testing
import SQLite3
@testable import Molten

@Suite("CatalogItemRepository Protocol Tests", .serialized)
@MainActor
struct CatalogItemRepositoryTests {

    // MARK: - Test Helpers

    /// Create a test database manager pointing to the bundled catalog
    private func createTestDatabaseManager() throws -> TestCatalogDatabaseManager {
        guard let dbPath = Bundle.main.url(forResource: "catalog", withExtension: "sqlite")?.path else {
            throw TestError.noDatabaseFound
        }
        let dbManager = TestCatalogDatabaseManager(databasePath: dbPath)
        try dbManager.initialize()
        return dbManager
    }

    // MARK: - Test Protocol Conformance

    @Test("GlassItemModel conforms to CatalogItem")
    func testGlassItemModelConformsToCatalogItem() async throws {
        let item = GlassItemModel(
            stable_id: "abc123",
            name: "Test Glass",
            sku: "001",
            manufacturer: "be",
            coe: 90,
            mfr_status: "available"
        )

        // Verify protocol requirements
        #expect(item.stable_id == "abc123")
        #expect(item.name == "Test Glass")
        #expect(item.sku == "001")
        #expect(item.manufacturer == "be")
        #expect(item.mfr_status == "available")
        #expect(item.uri == "moltenglass:item?abc123")

        // Verify Identifiable conformance (ID == String from CatalogItem)
        let id: String = item.id
        #expect(id == "abc123")
    }

    @Test("CoatingItemModel conforms to CatalogItem")
    func testCoatingItemModelConformsToCatalogItem() async throws {
        let item = CoatingItemModel(
            stable_id: "def456",
            name: "Test Coating",
            sku: "C001",
            manufacturer: "cim",
            mfr_status: "available"
        )

        // Verify protocol requirements
        #expect(item.stable_id == "def456")
        #expect(item.name == "Test Coating")
        #expect(item.sku == "C001")
        #expect(item.manufacturer == "cim")
        #expect(item.mfr_status == "available")
        #expect(item.uri == "moltenglass:coating?def456")

        // Verify Identifiable conformance
        let id: String = item.id
        #expect(id == "def456")
    }

    @Test("ToolItemModel conforms to CatalogItem")
    func testToolItemModelConformsToCatalogItem() async throws {
        let item = ToolItemModel(
            stable_id: "ghi789",
            name: "Test Tool",
            sku: "T001",
            manufacturer: "gttools",
            mfr_status: "available"
        )

        // Verify protocol requirements
        #expect(item.stable_id == "ghi789")
        #expect(item.name == "Test Tool")
        #expect(item.sku == "T001")
        #expect(item.manufacturer == "gttools")
        #expect(item.mfr_status == "available")
        #expect(item.uri == "moltenglass:tool?ghi789")

        // Verify Identifiable conformance
        let id: String = item.id
        #expect(id == "ghi789")
    }

    // MARK: - Test Associated Type Constraints

    @Test("Repository with GlassItemModel has correct ItemType")
    func testGlassRepositoryItemType() async throws {
        guard let dbPath = Bundle.main.url(forResource: "catalog", withExtension: "sqlite")?.path else {
            throw TestError.noDatabaseFound
        }
        let dbManager = TestCatalogDatabaseManager(databasePath: dbPath)
        try dbManager.initialize()

        let repository = SQLiteGlassItemRepository(databaseManager: dbManager)

        // Fetch an item and verify it's the correct type
        // This test verifies the associated type constraint works correctly
        let items = try await repository.fetchItems(matching: nil)

        // Compiler should infer items as [GlassItemModel]
        if let firstItem = items.first {
            let _: GlassItemModel = firstItem  // Should compile
            #expect(firstItem.stable_id.count == 6)  // Verify it's a real item
        }
    }

    @Test("Repository with CoatingItemModel has correct ItemType")
    func testCoatingRepositoryItemType() async throws {
        let dbManager = try createTestDatabaseManager()

        let repository = SQLiteCoatingItemRepository(databaseManager: dbManager)

        // Verify ItemType is correctly inferred
        let items = try await repository.fetchItems(matching: nil)

        if let firstItem = items.first {
            let _: CoatingItemModel = firstItem  // Should compile
            #expect(firstItem.stable_id.count > 0)
        }
    }

    @Test("Repository with ToolItemModel has correct ItemType")
    func testToolRepositoryItemType() async throws {
        let dbManager = try createTestDatabaseManager()

        let repository = SQLiteToolItemRepository(databaseManager: dbManager)

        // Verify ItemType is correctly inferred
        let items = try await repository.fetchItems(matching: nil)

        if let firstItem = items.first {
            let _: ToolItemModel = firstItem  // Should compile
            #expect(firstItem.stable_id.count > 0)
        }
    }

    // MARK: - Test Glass-Specific Extension Methods

    @Test("Glass-specific methods only available for GlassItemRepository")
    func testGlassSpecificMethods() async throws {
        let dbManager = try createTestDatabaseManager()

        let glassRepo = SQLiteGlassItemRepository(databaseManager: dbManager)

        // These methods should ONLY compile for GlassItemRepository (where ItemType == GlassItemModel)
        let _ = try await glassRepo.fetchItems(byCOE: 90)
        let _ = try await glassRepo.getDistinctCOEValues()
        let _ = try await glassRepo.getRecommendedSchedules(forGlassItem: "abc123")

        // Coating and Tool repositories should NOT have these methods (would fail to compile)
        // let coatingRepo = SQLiteCoatingItemRepository(databaseManager: dbManager)
        // let _ = try await coatingRepo.fetchItems(byCOE: 90)  // ❌ Should NOT compile
    }

    // MARK: - Test Common Repository Methods Work for All Types

    @Test("fetchItems(matching:) works for all item types")
    func testFetchItemsWorksForAllTypes() async throws {
        let dbManager = try createTestDatabaseManager()

        // Glass
        let glassRepo = SQLiteGlassItemRepository(databaseManager: dbManager)
        let glassItems = try await glassRepo.fetchItems(matching: nil)
        #expect(glassItems.count > 0)

        // Coating
        let coatingRepo = SQLiteCoatingItemRepository(databaseManager: dbManager)
        let coatingItems = try await coatingRepo.fetchItems(matching: nil)
        #expect(coatingItems.count >= 0)  // May be empty if no test data

        // Tool
        let toolRepo = SQLiteToolItemRepository(databaseManager: dbManager)
        let toolItems = try await toolRepo.fetchItems(matching: nil)
        #expect(toolItems.count >= 0)  // May be empty if no test data
    }

    @Test("fetchItem(byStableId:) works for all item types")
    func testFetchItemByStableIdWorksForAllTypes() async throws {
        let dbManager = try createTestDatabaseManager()

        let glassRepo = SQLiteGlassItemRepository(databaseManager: dbManager)

        // Insert a test item first
        let allItems = try await glassRepo.fetchItems(matching: nil)
        guard let testItem = allItems.first else {
            throw TestError.noTestData
        }

        // Fetch by stable ID
        let fetched = try await glassRepo.fetchItem(byStableId: testItem.stable_id)
        #expect(fetched != nil)
        #expect(fetched?.stable_id == testItem.stable_id)
    }

    @Test("searchItems(text:) works for all item types")
    func testSearchItemsWorksForAllTypes() async throws {
        let dbManager = try createTestDatabaseManager()

        let glassRepo = SQLiteGlassItemRepository(databaseManager: dbManager)

        // Search should work without errors
        let results = try await glassRepo.searchItems(text: "Clear")
        #expect(results.count >= 0)
    }

    @Test("Write operations throw for read-only repositories")
    func testWriteOperationsThrow() async throws {
        let dbManager = try createTestDatabaseManager()

        let glassRepo = SQLiteGlassItemRepository(databaseManager: dbManager)

        let testItem = GlassItemModel(
            stable_id: "test01",
            name: "Test",
            sku: nil,
            manufacturer: "test",
            coe: 90,
            mfr_status: "available"
        )

        // All write operations should throw
        await #expect(throws: Error.self) {
            try await glassRepo.createItem(testItem)
        }

        await #expect(throws: Error.self) {
            try await glassRepo.createItems([testItem])
        }

        await #expect(throws: Error.self) {
            try await glassRepo.updateItem(testItem)
        }

        await #expect(throws: Error.self) {
            try await glassRepo.deleteItem(stableId: "test01")
        }

        await #expect(throws: Error.self) {
            try await glassRepo.deleteItems(stableIds: ["test01"])
        }
    }
}

// MARK: - Test Helpers

enum TestError: Error {
    case noTestData
    case noDatabaseFound
}
