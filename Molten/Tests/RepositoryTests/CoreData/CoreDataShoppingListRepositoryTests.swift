//
//  CoreDataShoppingListRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataShoppingListRepository - manages shopping list items
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data ShoppingList Repository Tests")
@MainActor
struct CoreDataShoppingListRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create shopping list item")
    func testCreateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0,
            store: "Test Store"
        )

        // Test
        let created = try await repository.createItem(item)

        // Verify
        #expect(created.item_stable_id == "test-123")
        #expect(created.quantity == 5.0)
        #expect(created.store == "Test Store")
    }

    @Test("Should throw error when creating duplicate item")
    func testCreateDuplicateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test & Verify
        do {
            _ = try await repository.createItem(item)
            Issue.record("Expected error for duplicate item")
        } catch {
            // Expected error
        }
    }

    // MARK: - Read Tests

    @Test("Should fetch item by ID")
    func testFetchItemById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let itemId = UUID()
        let item = ItemShoppingModel(
            id: itemId,
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        let fetched = try await repository.fetchItem(byId: itemId)

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.id == itemId)
        #expect(fetched?.item_stable_id == "test-123")
    }

    @Test("Should fetch item by stable_id")
    func testFetchItemByStableId() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        let fetched = try await repository.fetchItem(forItem: "test-123")

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.item_stable_id == "test-123")
    }

    @Test("Should return nil for non-existent item")
    func testFetchNonExistentItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.fetchItem(forItem: "nonexistent")

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should fetch all items")
    func testFetchAllItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0))

        // Test
        let items = try await repository.fetchAllItems()

        // Verify
        #expect(items.count == 2)
    }

    @Test("Should fetch items for store")
    func testFetchItemsForStore() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(
            item_stable_id: "test-1",
            quantity: 1.0,
            store: "Store A"
        ))
        _ = try await repository.createItem(ItemShoppingModel(
            item_stable_id: "test-2",
            quantity: 2.0,
            store: "Store B"
        ))

        // Test
        let items = try await repository.fetchItems(forStore: "Store A")

        // Verify
        #expect(items.count == 1)
        #expect(items[0].store == "Store A")
    }

    // MARK: - Update Tests

    @Test("Should update existing item")
    func testUpdateItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let itemId = UUID()
        let original = ItemShoppingModel(
            id: itemId,
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(original)

        // Test
        let updated = ItemShoppingModel(
            id: itemId,
            item_stable_id: "test-123",
            quantity: 10.0
        )
        _ = try await repository.updateItem(updated)

        // Verify
        let fetched = try await repository.fetchItem(byId: itemId)
        #expect(fetched?.quantity == 10.0)
    }

    @Test("Should throw error when updating non-existent item")
    func testUpdateNonExistentItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )

        // Test & Verify
        do {
            _ = try await repository.updateItem(item)
            Issue.record("Expected error for updating non-existent item")
        } catch {
            // Expected error
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete item by ID")
    func testDeleteItemById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let itemId = UUID()
        let item = ItemShoppingModel(
            id: itemId,
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        try await repository.deleteItem(id: itemId)

        // Verify
        let fetched = try await repository.fetchItem(byId: itemId)
        #expect(fetched == nil)
    }

    @Test("Should delete item by stable_id")
    func testDeleteItemByStableId() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        try await repository.deleteItem(forItem: "test-123")

        // Verify
        let fetched = try await repository.fetchItem(forItem: "test-123")
        #expect(fetched == nil)
    }

    @Test("Should delete all items")
    func testDeleteAllItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0))

        // Test
        try await repository.deleteAllItems()

        // Verify
        let items = try await repository.fetchAllItems()
        #expect(items.isEmpty)
    }

    // MARK: - Quantity Operations Tests

    @Test("Should update quantity")
    func testUpdateQuantity() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        let updated = try await repository.updateQuantity(10.0, forItem: "test-123")

        // Verify
        #expect(updated.quantity == 10.0)
    }

    @Test("Should add quantity to existing item")
    func testAddQuantityToExisting() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0
        )
        _ = try await repository.createItem(item)

        // Test
        let updated = try await repository.addQuantity(3.0, toItem: "test-123", store: nil)

        // Verify
        #expect(updated.quantity == 8.0)
    }

    @Test("Should create new item when adding quantity to non-existent item")
    func testAddQuantityCreatesNew() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let created = try await repository.addQuantity(5.0, toItem: "test-123", store: "Test Store")

        // Verify
        #expect(created.quantity == 5.0)
        #expect(created.item_stable_id == "test-123")
        #expect(created.store == "Test Store")
    }

    // MARK: - Store Operations Tests

    @Test("Should update store")
    func testUpdateStore() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let item = ItemShoppingModel(
            item_stable_id: "test-123",
            quantity: 5.0,
            store: "Store A"
        )
        _ = try await repository.createItem(item)

        // Test
        let updated = try await repository.updateStore("Store B", forItem: "test-123")

        // Verify
        #expect(updated.store == "Store B")
    }

    @Test("Should get distinct stores")
    func testGetDistinctStores() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-3", quantity: 3.0, store: "Store B"))

        // Test
        let stores = try await repository.getDistinctStores()

        // Verify
        #expect(stores.count == 2)
        #expect(stores.contains("Store A"))
        #expect(stores.contains("Store B"))
    }

    @Test("Should get item count by store")
    func testGetItemCountByStore() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-3", quantity: 3.0, store: "Store B"))

        // Test
        let counts = try await repository.getItemCountByStore()

        // Verify
        #expect(counts["Store A"] == 2)
        #expect(counts["Store B"] == 1)
    }

    // MARK: - Discovery Operations Tests

    @Test("Should check if item is in list")
    func testIsItemInList() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-123", quantity: 5.0))

        // Test
        let exists = try await repository.isItemInList("test-123")
        let notExists = try await repository.isItemInList("nonexistent")

        // Verify
        #expect(exists == true)
        #expect(notExists == false)
    }

    @Test("Should get total item count")
    func testGetItemCount() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0))

        // Test
        let count = try await repository.getItemCount()

        // Verify
        #expect(count == 2)
    }

    @Test("Should get item count for store")
    func testGetItemCountForStore() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0, store: "Store B"))

        // Test
        let count = try await repository.getItemCount(forStore: "Store A")

        // Verify
        #expect(count == 1)
    }

    @Test("Should get items sorted by date")
    func testGetItemsSortedByDate() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        _ = try await repository.createItem(ItemShoppingModel(
            item_stable_id: "test-1",
            quantity: 1.0,
            dateAdded: date2
        ))
        _ = try await repository.createItem(ItemShoppingModel(
            item_stable_id: "test-2",
            quantity: 2.0,
            dateAdded: date1
        ))

        // Test - ascending
        let itemsAsc = try await repository.getItemsSortedByDate(ascending: true)

        // Verify
        #expect(itemsAsc[0].item_stable_id == "test-2")
        #expect(itemsAsc[1].item_stable_id == "test-1")
    }

    @Test("Should get items sorted by quantity")
    func testGetItemsSortedByQuantity() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 10.0))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 5.0))

        // Test - ascending
        let itemsAsc = try await repository.getItemsSortedByQuantity(ascending: true)

        // Verify
        #expect(itemsAsc[0].quantity == 5.0)
        #expect(itemsAsc[1].quantity == 10.0)
    }

    // MARK: - Batch Operations Tests

    @Test("Should add multiple items in batch")
    func testAddItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let items = [
            ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0),
            ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0)
        ]

        // Test
        let created = try await repository.addItems(items)

        // Verify
        #expect(created.count == 2)

        let all = try await repository.fetchAllItems()
        #expect(all.count == 2)
    }

    @Test("Should delete multiple items by IDs")
    func testDeleteItemsByIds() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let id1 = UUID()
        let id2 = UUID()

        _ = try await repository.createItem(ItemShoppingModel(id: id1, item_stable_id: "test-1", quantity: 1.0))
        _ = try await repository.createItem(ItemShoppingModel(id: id2, item_stable_id: "test-2", quantity: 2.0))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-3", quantity: 3.0))

        // Test
        try await repository.deleteItems(ids: [id1, id2])

        // Verify
        let remaining = try await repository.fetchAllItems()
        #expect(remaining.count == 1)
        #expect(remaining[0].item_stable_id == "test-3")
    }

    @Test("Should delete items for store")
    func testDeleteItemsForStore() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-1", quantity: 1.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-2", quantity: 2.0, store: "Store A"))
        _ = try await repository.createItem(ItemShoppingModel(item_stable_id: "test-3", quantity: 3.0, store: "Store B"))

        // Test
        try await repository.deleteItems(forStore: "Store A")

        // Verify
        let remaining = try await repository.fetchAllItems()
        #expect(remaining.count == 1)
        #expect(remaining[0].store == "Store B")
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataShoppingListRepository {
        RepositoryFactory.configureForTestingWithCoreData(controller: controller)
        return CoreDataShoppingListRepository(context: controller.container.viewContext)
    }
}
