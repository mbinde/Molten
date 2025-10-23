//
//  CoreDataGlassItemRepositoryStableIdTests.swift
//  Molten
//
//  Tests for CoreDataGlassItemRepository stable_id functionality
//

import Testing
import Foundation
@preconcurrency import CoreData
@testable import Molten

/// Tests for CoreDataGlassItemRepository stable_id handling using isolated Core Data stack
@Suite("CoreDataGlassItemRepository Stable ID Tests")
@MainActor
struct CoreDataGlassItemRepositoryStableIdTests {

    // MARK: - Test Setup

    let repository: GlassItemRepository

    init() async throws {
        // Configure factory for testing with Core Data
        RepositoryFactory.configureForTestingWithCoreData()

        // Create repository using factory
        repository = RepositoryFactory.createGlassItemRepository()
    }

    // MARK: - Create Tests with Stable ID

    @Test("Create glass item with stable_id")
    func testCreateItemWithStableId() async throws {
        let item = GlassItemModel(
            natural_key: "bullseye-001-001",
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            mfr_notes: "Test notes",
            coe: 90,
            url: "https://example.com",
            mfr_status: "available",
            image_url: "https://example.com/image.jpg",
            image_path: "/images/001.jpg"
        )

        let created = try await repository.createItem(item)

        #expect(created.natural_key == "bullseye-001-001")
        #expect(created.stable_id == "abc123")
        #expect(created.name == "Clear Rod")
    }

    @Test("Create glass item without stable_id")
    func testCreateItemWithoutStableId() async throws {
        let item = GlassItemModel(
            natural_key: "bullseye-002-001",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        #expect(created.natural_key == "bullseye-002-001")
        #expect(created.stable_id == nil)
        #expect(created.name == "Blue Rod")
    }

    @Test("Create glass item with nil stable_id")
    func testCreateItemWithExplicitNilStableId() async throws {
        let item = GlassItemModel(
            natural_key: "bullseye-003-001",
            stable_id: nil,
            name: "Red Rod",
            sku: "003",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        #expect(created.natural_key == "bullseye-003-001")
        #expect(created.stable_id == nil)
    }

    // MARK: - Read Tests with Stable ID

    @Test("Get item by natural key includes stable_id")
    func testGetItemByNaturalKeyIncludesStableId() async throws {
        // Create item with stable_id
        let item = GlassItemModel(
            natural_key: "bullseye-010-001",
            stable_id: "xyz789",
            name: "Test Rod",
            sku: "010",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(item)

        // Fetch it back
        let fetched = try await repository.fetchItem(byStableId: "bullseye-010-001")

        #expect(fetched != nil)
        #expect(fetched?.natural_key == "bullseye-010-001")
        #expect(fetched?.stable_id == "xyz789")
    }

    @Test("Get all items includes stable_id for all items")
    func testGetAllItemsIncludesStableId() async throws {
        // Create items with and without stable_id
        let item1 = GlassItemModel(
            natural_key: "bullseye-020-001",
            stable_id: "aaa111",
            name: "Item 1",
            sku: "020",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            natural_key: "bullseye-021-001",
            name: "Item 2",
            sku: "021",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        _ = try await repository.createItem(item1)
        _ = try await repository.createItem(item2)

        // Fetch all
        let allItems = try await repository.fetchItems(matching: nil)

        let fetchedItem1 = allItems.first { $0.natural_key == "bullseye-020-001" }
        let fetchedItem2 = allItems.first { $0.natural_key == "bullseye-021-001" }

        #expect(fetchedItem1?.stable_id == "aaa111")
        #expect(fetchedItem2?.stable_id == nil)
    }

    // MARK: - Update Tests with Stable ID

    @Test("Update item preserves existing stable_id")
    func testUpdateItemPreservesStableId() async throws {
        // Create item with stable_id
        let original = GlassItemModel(
            natural_key: "bullseye-030-001",
            stable_id: "preserve",
            name: "Original Name",
            sku: "030",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Update the item (change name but keep stable_id)
        let updated = GlassItemModel(
            natural_key: "bullseye-030-001",
            stable_id: "preserve",
            name: "Updated Name",
            sku: "030",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        // Fetch and verify stable_id is preserved
        let fetched = try await repository.fetchItem(byStableId: "bullseye-030-001")

        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.stable_id == "preserve")
    }

    @Test("Update can add stable_id to existing item")
    func testUpdateCanAddStableId() async throws {
        // Create item without stable_id
        let original = GlassItemModel(
            natural_key: "bullseye-040-001",
            name: "Item without ID",
            sku: "040",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Update to add stable_id
        let updated = GlassItemModel(
            natural_key: "bullseye-040-001",
            stable_id: "newid123",
            name: "Item without ID",
            sku: "040",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        // Fetch and verify stable_id was added
        let fetched = try await repository.fetchItem(byStableId: "bullseye-040-001")

        #expect(fetched?.stable_id == "newid123")
    }

    @Test("Update can change stable_id (migration scenario)")
    func testUpdateCanChangeStableId() async throws {
        // Create item with stable_id
        let original = GlassItemModel(
            natural_key: "bullseye-050-001",
            stable_id: "oldid",
            name: "Test Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Update with new stable_id
        let updated = GlassItemModel(
            natural_key: "bullseye-050-001",
            stable_id: "newid",
            name: "Test Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        // Fetch and verify stable_id was changed
        let fetched = try await repository.fetchItem(byStableId: "bullseye-050-001")

        #expect(fetched?.stable_id == "newid")
    }

    // MARK: - Batch Operations with Stable ID

    @Test("Batch create items with stable_ids")
    func testBatchCreateWithStableIds() async throws {
        let items = [
            GlassItemModel(
                natural_key: "bullseye-060-001",
                stable_id: "batch1",
                name: "Batch Item 1",
                sku: "060",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "bullseye-061-001",
                stable_id: "batch2",
                name: "Batch Item 2",
                sku: "061",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "bullseye-062-001",
                name: "Batch Item 3",
                sku: "062",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )
        ]

        try await repository.createItems(items)

        // Verify all items were created with correct stable_ids
        let item1 = try await repository.fetchItem(byStableId: "bullseye-060-001")
        let item2 = try await repository.fetchItem(byStableId: "bullseye-061-001")
        let item3 = try await repository.fetchItem(byStableId: "bullseye-062-001")

        #expect(item1?.stable_id == "batch1")
        #expect(item2?.stable_id == "batch2")
        #expect(item3?.stable_id == nil)
    }

    // MARK: - Persistence Tests

    @Test("Stable ID persists across fetch operations")
    func testStableIdPersists() async throws {
        let item = GlassItemModel(
            natural_key: "bullseye-070-001",
            stable_id: "persist",
            name: "Persistence Test",
            sku: "070",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(item)

        // Fetch multiple times
        let fetch1 = try await repository.fetchItem(byStableId: "bullseye-070-001")
        let fetch2 = try await repository.fetchItem(byStableId: "bullseye-070-001")
        let allItems = try await repository.fetchItems(matching: nil)
        let fetch3 = allItems.first { $0.natural_key == "bullseye-070-001" }

        #expect(fetch1?.stable_id == "persist")
        #expect(fetch2?.stable_id == "persist")
        #expect(fetch3?.stable_id == "persist")
    }

    // MARK: - Edge Cases

    @Test("Create item with 6-character stable_id")
    func testCreateWith6CharStableId() async throws {
        let item = GlassItemModel(
            natural_key: "bullseye-080-001",
            stable_id: "3DyUbA",
            name: "6-char ID test",
            sku: "080",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        #expect(created.stable_id == "3DyUbA")
        #expect(created.stable_id?.count == 6)
    }

    @Test("Create items with various stable_id formats")
    func testCreateWithVariousStableIdFormats() async throws {
        let testIds = ["3DyUbA", "5fJhrx", "1ya3bn", "5aZhHE", "2bfEjE"]

        for (index, stableId) in testIds.enumerated() {
            let item = GlassItemModel(
                natural_key: "bullseye-\(100 + index)-001",
                stable_id: stableId,
                name: "Test \(index)",
                sku: "\(100 + index)",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )

            _ = try await repository.createItem(item)

            // Verify it was stored correctly
            let fetched = try await repository.fetchItem(byStableId: item.natural_key)
            #expect(fetched?.stable_id == stableId)
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Items without stable_id work normally")
    func testItemsWithoutStableIdWorkNormally() async throws {
        // Create, update, and fetch items without stable_id
        let item = GlassItemModel(
            natural_key: "bullseye-200-001",
            name: "Legacy Item",
            sku: "200",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)
        #expect(created.stable_id == nil)

        let fetched = try await repository.fetchItem(byStableId: "bullseye-200-001")
        #expect(fetched?.stable_id == nil)

        let updated = GlassItemModel(
            natural_key: "bullseye-200-001",
            name: "Updated Legacy Item",
            sku: "200",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        let fetchedAfterUpdate = try await repository.fetchItem(byStableId: "bullseye-200-001")
        #expect(fetchedAfterUpdate?.name == "Updated Legacy Item")
        #expect(fetchedAfterUpdate?.stable_id == nil)
    }

    @Test("Mix of items with and without stable_id")
    func testMixOfItemsWithAndWithoutStableId() async throws {
        // Create multiple items, some with stable_id and some without
        let items = [
            GlassItemModel(
                natural_key: "bullseye-210-001",
                stable_id: "with1",
                name: "With ID 1",
                sku: "210",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "bullseye-211-001",
                name: "Without ID",
                sku: "211",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "bullseye-212-001",
                stable_id: "with2",
                name: "With ID 2",
                sku: "212",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )
        ]

        try await repository.createItems(items)

        let allItems = try await repository.fetchItems(matching: nil)
        let withIds = allItems.filter { $0.stable_id != nil }
        let withoutIds = allItems.filter { $0.stable_id == nil }

        #expect(withIds.count >= 2)  // At least our 2 items with IDs
        #expect(withoutIds.count >= 1)  // At least our 1 item without ID
    }
}
