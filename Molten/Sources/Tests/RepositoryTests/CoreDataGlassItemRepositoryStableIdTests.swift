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

        #expect(created.stable_id == "abc123")
        #expect(created.name == "Clear Rod")
    }

    @Test("Create glass item without stable_id")
    func testCreateItemWithoutStableId() async throws {
        let item = GlassItemModel(
            stable_id: "bullseye-002-001",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        // Item created with manufacturer-sku format as stable_id
        #expect(created.stable_id == "bullseye-002-001")
        #expect(created.name == "Blue Rod")
    }

    @Test("Create glass item with natural_key format as stable_id")
    func testCreateItemWithNaturalKeyFormatAsStableId() async throws {
        let item = GlassItemModel(
            stable_id: "bullseye-003-001",
            name: "Red Rod",
            sku: "003",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        #expect(created.stable_id == "bullseye-003-001")
    }

    // MARK: - Read Tests with Stable ID

    @Test("Get item by stable_id includes all properties")
    func testGetItemByStableIdIncludesAllProperties() async throws {
        // Create item with stable_id
        let item = GlassItemModel(
            stable_id: "xyz789",
            name: "Test Rod",
            sku: "010",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let created = try await repository.createItem(item)

        // Fetch it back using the stable_id
        let fetched = try await repository.fetchItem(byStableId: "xyz789")

        #expect(fetched != nil)
        #expect(fetched?.stable_id == "xyz789")
        #expect(created.stable_id == "xyz789")
        #expect(fetched?.name == "Test Rod")
        #expect(fetched?.sku == "010")
        #expect(fetched?.manufacturer == "bullseye")
    }

    @Test("Get all items includes stable_id for all items")
    func testGetAllItemsIncludesStableId() async throws {
        // Create items with and without stable_id
        let item1 = GlassItemModel(
            stable_id: "aaa111",
            name: "Item 1",
            sku: "020",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "bullseye-021-001",
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

        let fetchedItem1 = allItems.first { $0.stable_id == "aaa111" }
        let fetchedItem2 = allItems.first { $0.stable_id == "bullseye-021-001" }

        #expect(fetchedItem1?.stable_id == "aaa111")
        #expect(fetchedItem2?.stable_id == "bullseye-021-001")
    }

    // MARK: - Update Tests with Stable ID

    @Test("Update item preserves existing stable_id")
    func testUpdateItemPreservesStableId() async throws {
        // Create item with stable_id
        let original = GlassItemModel(
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
            stable_id: "preserve",
            name: "Updated Name",
            sku: "030",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        // Fetch and verify stable_id is preserved (use the actual stable_id)
        let fetched = try await repository.fetchItem(byStableId: "preserve")

        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.stable_id == "preserve")
    }

    @Test("Update item with custom stable_id updates properties correctly")
    func testUpdateItemWithCustomStableId() async throws {
        // Create item with custom stable_id
        let original = GlassItemModel(
            stable_id: "custom40",
            name: "Original Name",
            sku: "040",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Update properties while keeping the same stable_id
        let updated = GlassItemModel(
            stable_id: "custom40",
            name: "Updated Name",
            sku: "040",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "discontinued"
        )
        try await repository.updateItem(updated)

        // Fetch and verify the update
        let fetched = try await repository.fetchItem(byStableId: "custom40")

        #expect(fetched?.stable_id == "custom40")
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.coe == 96)
        #expect(fetched?.mfr_status == "discontinued")
    }

    @Test("Creating item with duplicate stable_id updates existing item")
    func testCreateWithDuplicateStableIdUpdatesExisting() async throws {
        // Create initial item
        let original = GlassItemModel(
            stable_id: "dup50",
            name: "Original Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Create "new" item with same stable_id but different properties
        let duplicate = GlassItemModel(
            stable_id: "dup50",
            name: "Updated Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "discontinued"
        )
        _ = try await repository.createItem(duplicate)

        // Fetch and verify the existing item was updated, not duplicated
        let fetched = try await repository.fetchItem(byStableId: "dup50")
        let allItems = try await repository.fetchItems(matching: nil)
        let matchingItems = allItems.filter { $0.stable_id == "dup50" }

        #expect(fetched?.stable_id == "dup50")
        #expect(fetched?.name == "Updated Item")
        #expect(fetched?.coe == 96)
        #expect(matchingItems.count == 1, "Should only have one item with this stable_id")
    }

    // MARK: - Batch Operations with Stable ID

    @Test("Batch create items with stable_ids")
    func testBatchCreateWithStableIds() async throws {
        let items = [
            GlassItemModel(
            stable_id: "batch1",
                name: "Batch Item 1",
                sku: "060",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
            stable_id: "batch2",
                name: "Batch Item 2",
                sku: "061",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
            stable_id: "bullseye-062-001",
            name: "Batch Item 3",
                sku: "062",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )
        ]

        try await repository.createItems(items)

        // Verify all items were created with correct stable_ids
        let item1 = try await repository.fetchItem(byStableId: "batch1")
        let item2 = try await repository.fetchItem(byStableId: "batch2")
        let item3 = try await repository.fetchItem(byStableId: "bullseye-062-001")

        #expect(item1?.stable_id == "batch1")
        #expect(item2?.stable_id == "batch2")
        #expect(item3?.stable_id == "bullseye-062-001")
    }

    // MARK: - Persistence Tests

    @Test("Stable ID persists across fetch operations")
    func testStableIdPersists() async throws {
        let item = GlassItemModel(
            stable_id: "persist",
            name: "Persistence Test",
            sku: "070",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(item)

        // Fetch multiple times using the actual stable_id
        let fetch1 = try await repository.fetchItem(byStableId: "persist")
        let fetch2 = try await repository.fetchItem(byStableId: "persist")
        let allItems = try await repository.fetchItems(matching: nil)
        let fetch3 = allItems.first { $0.stable_id == "persist" }

        #expect(fetch1?.stable_id == "persist")
        #expect(fetch2?.stable_id == "persist")
        #expect(fetch3?.stable_id == "persist")
    }

    // MARK: - Edge Cases

    @Test("Create item with 6-character stable_id")
    func testCreateWith6CharStableId() async throws {
        let item = GlassItemModel(
            stable_id: "3DyUbA",
            name: "6-char ID test",
            sku: "080",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)

        #expect(created.stable_id == "3DyUbA")
        #expect(created.stable_id.count == 6)
    }

    @Test("Create items with various stable_id formats")
    func testCreateWithVariousStableIdFormats() async throws {
        let testIds = ["3DyUbA", "5fJhrx", "1ya3bn", "5aZhHE", "2bfEjE"]

        for (index, stableId) in testIds.enumerated() {
            let item = GlassItemModel(
                stable_id: stableId,
                name: "Test \(index)",
                sku: "\(100 + index)",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )

            let created = try await repository.createItem(item)

            // Verify it was stored correctly
            #expect(created.stable_id == stableId, "Created item should have the correct stable_id")
            let fetched = try await repository.fetchItem(byStableId: stableId)
            #expect(fetched?.stable_id == stableId)
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Items without stable_id work normally")
    func testItemsWithoutStableIdWorkNormally() async throws {
        // Create, update, and fetch items using natural key format as stable_id
        let item = GlassItemModel(
            stable_id: "bullseye-200-001",
            name: "Legacy Item",
            sku: "200",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let created = try await repository.createItem(item)
        #expect(created.stable_id == "bullseye-200-001")

        let fetched = try await repository.fetchItem(byStableId: "bullseye-200-001")
        #expect(fetched?.stable_id == "bullseye-200-001")

        let updated = GlassItemModel(
            stable_id: "bullseye-200-001",
            name: "Updated Legacy Item",
            sku: "200",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        try await repository.updateItem(updated)

        let fetchedAfterUpdate = try await repository.fetchItem(byStableId: "bullseye-200-001")
        #expect(fetchedAfterUpdate?.name == "Updated Legacy Item")
        #expect(fetchedAfterUpdate?.stable_id == "bullseye-200-001")
    }

    @Test("Mix of items with different stable_id formats")
    func testMixOfItemsWithAndWithoutStableId() async throws {
        // Create multiple items with different stable_id formats
        let items = [
            GlassItemModel(
            stable_id: "with1",
                name: "With ID 1",
                sku: "210",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
            stable_id: "bullseye-211-001",
            name: "Natural Key Format",
                sku: "211",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
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
        let item1 = allItems.first { $0.stable_id == "with1" }
        let item2 = allItems.first { $0.stable_id == "bullseye-211-001" }
        let item3 = allItems.first { $0.stable_id == "with2" }

        #expect(item1?.stable_id == "with1")
        #expect(item2?.stable_id == "bullseye-211-001")
        #expect(item3?.stable_id == "with2")
    }
}
