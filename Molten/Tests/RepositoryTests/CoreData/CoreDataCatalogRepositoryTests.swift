//
//  CoreDataCatalogRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataCatalogRepository - manages catalog item data
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data Catalog Repository Tests")
@MainActor
struct CoreDataCatalogRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create catalog item")
    func testCreateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            name: "Test Rod",
            code: "TEST-001",
            manufacturer: "test"
        )

        // Test
        let created = try await repository.createItem(item)

        // Verify
        #expect(created.name == "Test Rod")
        #expect(created.code == "TEST-001")
        #expect(created.manufacturer == "test")
        #expect(created.item_type == "rod")
    }

    @Test("Should create catalog item with parent ID")
    func testCreateItemWithParent() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Child Item",
            code: "CHILD-001",
            manufacturer: "test"
        )

        // Test
        let created = try await repository.createItem(item, parentId: parentId)

        // Verify
        #expect(created.parent_id == parentId)
        #expect(created.name == "Child Item")
    }

    @Test("Should create multiple items in batch")
    func testCreateItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let items = [
            CatalogItemModel(
                parent_id: parentId,
                item_type: "rod",
                name: "Item 1",
                code: "TEST-001",
                manufacturer: "test"
            ),
            CatalogItemModel(
                parent_id: parentId,
                item_type: "tube",
                name: "Item 2",
                code: "TEST-002",
                manufacturer: "test"
            )
        ]

        // Test
        let created = try await repository.createItems(items)

        // Verify
        #expect(created.count == 2)
        #expect(created[0].name == "Item 1")
        #expect(created[1].name == "Item 2")
    }

    // MARK: - Read Tests

    @Test("Should fetch item by string ID")
    func testFetchItemById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        let fetched = try await repository.fetchItem(id: "test-123")

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.name == "Test Item")
        #expect(fetched?.id == "test-123")
    }

    @Test("Should fetch item by UUID")
    func testFetchItemByUUID() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let itemId = UUID()
        let item = CatalogItemModel(
            id2: itemId,
            parent_id: parentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        let fetched = try await repository.fetchItem(id2: itemId)

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.id2 == itemId)
        #expect(fetched?.name == "Test Item")
    }

    @Test("Should return nil for non-existent item")
    func testFetchNonExistentItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.fetchItem(id: "nonexistent")

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should fetch all items")
    func testGetAllItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Item 1",
            code: "TEST-001",
            manufacturer: "test"
        ))
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "tube",
            name: "Item 2",
            code: "TEST-002",
            manufacturer: "test"
        ))

        // Test
        let items = try await repository.getAllItems()

        // Verify
        #expect(items.count == 2)
    }

    @Test("Should fetch items for parent")
    func testFetchItemsForParent() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parent1 = UUID()
        let parent2 = UUID()

        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parent1,
            item_type: "rod",
            name: "Parent 1 Item",
            code: "P1-001",
            manufacturer: "test"
        ))
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parent2,
            item_type: "rod",
            name: "Parent 2 Item",
            code: "P2-001",
            manufacturer: "test"
        ))

        // Test
        let parent1Items = try await repository.fetchItems(for: parent1)

        // Verify
        #expect(parent1Items.count == 1)
        #expect(parent1Items[0].name == "Parent 1 Item")
    }

    // MARK: - Update Tests

    @Test("Should update existing item")
    func testUpdateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Original Name",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test - Update the item
        let updatedItem = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Updated Name",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.updateItem(updatedItem)

        // Verify
        let fetched = try await repository.fetchItem(id: "test-123")
        #expect(fetched?.name == "Updated Name")
    }

    @Test("Should update multiple items in batch")
    func testUpdateItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item1 = CatalogItemModel(
            id: "test-1",
            parent_id: parentId,
            item_type: "rod",
            name: "Item 1",
            code: "TEST-001",
            manufacturer: "test"
        )
        let item2 = CatalogItemModel(
            id: "test-2",
            parent_id: parentId,
            item_type: "rod",
            name: "Item 2",
            code: "TEST-002",
            manufacturer: "test"
        )
        _ = try await repository.createItems([item1, item2])

        // Test - Update both items
        let updatedItem1 = CatalogItemModel(
            id: "test-1",
            parent_id: parentId,
            item_type: "rod",
            name: "Updated 1",
            code: "TEST-001",
            manufacturer: "test"
        )
        let updatedItem2 = CatalogItemModel(
            id: "test-2",
            parent_id: parentId,
            item_type: "rod",
            name: "Updated 2",
            code: "TEST-002",
            manufacturer: "test"
        )
        _ = try await repository.updateItems([updatedItem1, updatedItem2])

        // Verify
        let fetched1 = try await repository.fetchItem(id: "test-1")
        let fetched2 = try await repository.fetchItem(id: "test-2")
        #expect(fetched1?.name == "Updated 1")
        #expect(fetched2?.name == "Updated 2")
    }

    @Test("Should update item parent relationship")
    func testUpdateItemParent() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let oldParentId = UUID()
        let newParentId = UUID()
        let itemId = UUID()

        let item = CatalogItemModel(
            id2: itemId,
            parent_id: oldParentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        let updated = try await repository.updateItemParent(itemId2: itemId, newParentId: newParentId)

        // Verify
        #expect(updated.parent_id == newParentId)
    }

    // MARK: - Delete Tests

    @Test("Should delete item by string ID")
    func testDeleteItemById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        try await repository.deleteItem(id: "test-123")

        // Verify
        let fetched = try await repository.fetchItem(id: "test-123")
        #expect(fetched == nil)
    }

    @Test("Should delete item by UUID")
    func testDeleteItemByUUID() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let itemId = UUID()
        let item = CatalogItemModel(
            id2: itemId,
            parent_id: parentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        try await repository.deleteItem(id2: itemId)

        // Verify
        let fetched = try await repository.fetchItem(id2: itemId)
        #expect(fetched == nil)
    }

    @Test("Should throw error when deleting non-existent item")
    func testDeleteNonExistentItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test & Verify
        do {
            try await repository.deleteItem(id: "nonexistent")
            Issue.record("Expected error for deleting non-existent item")
        } catch {
            // Expected error
        }
    }

    // MARK: - Search Tests

    @Test("Should search items by text")
    func testSearchItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Clear Rod",
            code: "CLR-001",
            manufacturer: "bullseye"
        ))
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Blue Rod",
            code: "BLU-001",
            manufacturer: "bullseye"
        ))

        // Test
        let results = try await repository.searchItems(text: "Clear")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].name == "Clear Rod")
    }

    @Test("Should search items by manufacturer")
    func testSearchByManufacturer() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Item 1",
            code: "TEST-001",
            manufacturer: "bullseye"
        ))
        _ = try await repository.createItem(CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Item 2",
            code: "TEST-002",
            manufacturer: "oceanside"
        ))

        // Test
        let results = try await repository.searchItems(text: "bullseye")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].manufacturer == "bullseye")
    }

    // MARK: - Migration Tests

    @Test("Should migrate item to UUID")
    func testMigrateItemToUUID() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            id: "legacy-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Legacy Item",
            code: "LEG-001",
            manufacturer: "test"
        )
        _ = try await repository.createItem(item)

        // Test
        let migrated = try await repository.migrateItemToUUID(legacyId: "legacy-123")

        // Verify
        #expect(migrated.id == "legacy-123")
        #expect(migrated.id2 != UUID(uuidString: "00000000-0000-0000-0000-000000000000")) // Has valid UUID
    }

    // MARK: - Validation Tests

    @Test("Should validate item relationships")
    func testValidateItemRelationships() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let item = CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "test"
        )

        // Test - Should not throw for valid item
        try await repository.validateItemRelationships(item)

        // If we get here, validation passed
        #expect(true)
    }

    @Test("Should detect changes between items")
    func testShouldUpdateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let parentId = UUID()
        let existing = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Original",
            code: "TEST-001",
            manufacturer: "test"
        )

        let updated = CatalogItemModel(
            id: "test-123",
            parent_id: parentId,
            item_type: "rod",
            name: "Updated",
            code: "TEST-001",
            manufacturer: "test"
        )

        // Test
        let shouldUpdate = try await repository.shouldUpdateItem(existing: existing, with: updated)

        // Verify
        #expect(shouldUpdate == true)
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataCatalogRepository {
        RepositoryFactory.configureForTestingWithCoreData(controller: controller)
        return CoreDataCatalogRepository(context: controller.container.viewContext)
    }
}
