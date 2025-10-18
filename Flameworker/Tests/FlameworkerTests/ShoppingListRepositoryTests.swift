//
//  ShoppingListRepositoryTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Flameworker

@Suite("Shopping List Repository Tests")
struct ShoppingListRepositoryTests {

    // MARK: - Setup Helper

    /// Create a fresh repository instance for each test
    private func createRepository() -> MockShoppingListRepository {
        let repo = MockShoppingListRepository()
        repo.clearAllData()
        return repo
    }

    // MARK: - Basic CRUD Operations Tests

    @Test("Create shopping list item successfully")
    func testCreateItem() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0,
            store: "Frantz Art Glass"
        )

        let created = try await repo.createItem(item)

        #expect(created.item_natural_key == "bullseye-001-0")
        #expect(created.quantity == 5.0)
        #expect(created.store == "Frantz Art Glass")
        #expect(created.id == item.id)
    }

    @Test("Create item with invalid data should fail")
    func testCreateItemWithInvalidData() async throws {
        let repo = createRepository()

        // Item with empty natural key
        let invalidItem = ItemShoppingModel(
            item_natural_key: "",
            quantity: 5.0,
            store: "Test Store"
        )

        do {
            _ = try await repo.createItem(invalidItem)
            Issue.record("Expected error for invalid data")
        } catch {
            // Expected error
            #expect(error is MockShoppingListRepositoryError)
        }
    }

    @Test("Create duplicate item should fail")
    func testCreateDuplicateItem() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0
        )

        _ = try await repo.createItem(item)

        // Try to create same item again
        do {
            _ = try await repo.createItem(item)
            Issue.record("Expected error for duplicate item")
        } catch let error as MockShoppingListRepositoryError {
            if case .itemAlreadyExists(let key) = error {
                #expect(key == "bullseye-001-0")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Fetch item by ID")
    func testFetchItemById() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "cim-874-0",
            quantity: 3.0,
            store: "Olympic Color"
        )

        let created = try await repo.createItem(item)
        let fetched = try await repo.fetchItem(byId: created.id)

        #expect(fetched != nil)
        #expect(fetched?.id == created.id)
        #expect(fetched?.item_natural_key == "cim-874-0")
    }

    @Test("Fetch item by natural key")
    func testFetchItemByNaturalKey() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "spectrum-96-0",
            quantity: 7.0
        )

        _ = try await repo.createItem(item)
        let fetched = try await repo.fetchItem(forItem: "spectrum-96-0")

        #expect(fetched != nil)
        #expect(fetched?.item_natural_key == "spectrum-96-0")
        #expect(fetched?.quantity == 7.0)
    }

    @Test("Fetch non-existent item returns nil")
    func testFetchNonExistentItem() async throws {
        let repo = createRepository()

        let fetched = try await repo.fetchItem(forItem: "non-existent-key")

        #expect(fetched == nil)
    }

    @Test("Fetch all items")
    func testFetchAllItems() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let allItems = try await repo.fetchAllItems()

        #expect(allItems.count == 3)
    }

    @Test("Update shopping list item")
    func testUpdateItem() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0,
            store: "Store A"
        )

        let created = try await repo.createItem(item)

        let updated = ItemShoppingModel(
            id: created.id,
            item_natural_key: "bullseye-001-0",
            quantity: 10.0,
            store: "Store B"
        )

        let result = try await repo.updateItem(updated)

        #expect(result.quantity == 10.0)
        #expect(result.store == "Store B")

        let fetched = try await repo.fetchItem(byId: created.id)
        #expect(fetched?.quantity == 10.0)
        #expect(fetched?.store == "Store B")
    }

    @Test("Update non-existent item should fail")
    func testUpdateNonExistentItem() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            id: UUID(),
            item_natural_key: "non-existent",
            quantity: 5.0
        )

        do {
            _ = try await repo.updateItem(item)
            Issue.record("Expected error for non-existent item")
        } catch {
            #expect(error is MockShoppingListRepositoryError)
        }
    }

    @Test("Delete item by ID")
    func testDeleteItemById() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0
        )

        let created = try await repo.createItem(item)

        try await repo.deleteItem(id: created.id)

        let fetched = try await repo.fetchItem(byId: created.id)
        #expect(fetched == nil)
    }

    @Test("Delete item by natural key")
    func testDeleteItemByNaturalKey() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "cim-874-0",
            quantity: 5.0
        )

        _ = try await repo.createItem(item)

        try await repo.deleteItem(forItem: "cim-874-0")

        let fetched = try await repo.fetchItem(forItem: "cim-874-0")
        #expect(fetched == nil)
    }

    @Test("Delete all items")
    func testDeleteAllItems() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        try await repo.deleteAllItems()

        let allItems = try await repo.fetchAllItems()
        #expect(allItems.isEmpty)
    }

    // MARK: - Quantity Operations Tests

    @Test("Update quantity for existing item")
    func testUpdateQuantity() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0
        )

        _ = try await repo.createItem(item)

        let updated = try await repo.updateQuantity(15.0, forItem: "bullseye-001-0")

        #expect(updated.quantity == 15.0)

        let fetched = try await repo.fetchItem(forItem: "bullseye-001-0")
        #expect(fetched?.quantity == 15.0)
    }

    @Test("Update quantity for non-existent item should fail")
    func testUpdateQuantityForNonExistentItem() async throws {
        let repo = createRepository()

        do {
            _ = try await repo.updateQuantity(10.0, forItem: "non-existent")
            Issue.record("Expected error for non-existent item")
        } catch {
            #expect(error is MockShoppingListRepositoryError)
        }
    }

    @Test("Add quantity to existing item")
    func testAddQuantityToExistingItem() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "cim-874-0",
            quantity: 5.0,
            store: "Store A"
        )

        _ = try await repo.createItem(item)

        let updated = try await repo.addQuantity(3.0, toItem: "cim-874-0", store: nil)

        #expect(updated.quantity == 8.0)
        #expect(updated.store == "Store A") // Store should remain unchanged
    }

    @Test("Add quantity creates new item if not exists")
    func testAddQuantityCreatesNewItem() async throws {
        let repo = createRepository()

        let created = try await repo.addQuantity(10.0, toItem: "new-item", store: "New Store")

        #expect(created.item_natural_key == "new-item")
        #expect(created.quantity == 10.0)
        #expect(created.store == "New Store")

        let fetched = try await repo.fetchItem(forItem: "new-item")
        #expect(fetched != nil)
        #expect(fetched?.quantity == 10.0)
    }

    // MARK: - Store Operations Tests

    @Test("Update store for item")
    func testUpdateStore() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0,
            store: "Store A"
        )

        _ = try await repo.createItem(item)

        let updated = try await repo.updateStore("Store B", forItem: "bullseye-001-0")

        #expect(updated.store == "Store B")
        #expect(updated.quantity == 5.0) // Quantity should remain unchanged
    }

    @Test("Fetch items by store")
    func testFetchItemsByStore() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, store: "Frantz Art Glass")
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let frantzItems = try await repo.fetchItems(forStore: "Frantz Art Glass")

        #expect(frantzItems.count == 2)
        #expect(frantzItems.allSatisfy { $0.store == "Frantz Art Glass" })
    }

    @Test("Get distinct stores")
    func testGetDistinctStores() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-4", quantity: 2.0, store: "Bullseye Glass Co")
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let stores = try await repo.getDistinctStores()

        #expect(stores.count == 3)
        #expect(stores.contains("Frantz Art Glass"))
        #expect(stores.contains("Olympic Color"))
        #expect(stores.contains("Bullseye Glass Co"))
    }

    @Test("Get item count by store")
    func testGetItemCountByStore() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-4", quantity: 2.0, store: nil)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let counts = try await repo.getItemCountByStore()

        #expect(counts["Frantz Art Glass"] == 2)
        #expect(counts["Olympic Color"] == 1)
        // Items without store should not be in the dictionary
    }

    // MARK: - Discovery Operations Tests

    @Test("Check if item is in list")
    func testIsItemInList() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0
        )

        _ = try await repo.createItem(item)

        let exists = try await repo.isItemInList("bullseye-001-0")
        let notExists = try await repo.isItemInList("non-existent")

        #expect(exists == true)
        #expect(notExists == false)
    }

    @Test("Get total item count")
    func testGetItemCount() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let count = try await repo.getItemCount()

        #expect(count == 3)
    }

    @Test("Get item count for specific store")
    func testGetItemCountForStore() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, store: "Frantz Art Glass")
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let frantzCount = try await repo.getItemCount(forStore: "Frantz Art Glass")
        let olympicCount = try await repo.getItemCount(forStore: "Olympic Color")

        #expect(frantzCount == 2)
        #expect(olympicCount == 1)
    }

    @Test("Get items sorted by date ascending")
    func testGetItemsSortedByDateAscending() async throws {
        let repo = createRepository()

        // Create items with different dates
        let now = Date()
        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, dateAdded: now.addingTimeInterval(-3600)),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, dateAdded: now.addingTimeInterval(-7200)),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, dateAdded: now)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let sorted = try await repo.getItemsSortedByDate(ascending: true)

        #expect(sorted.count == 3)
        #expect(sorted[0].item_natural_key == "item-2") // Oldest
        #expect(sorted[1].item_natural_key == "item-1")
        #expect(sorted[2].item_natural_key == "item-3") // Newest
    }

    @Test("Get items sorted by date descending")
    func testGetItemsSortedByDateDescending() async throws {
        let repo = createRepository()

        let now = Date()
        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, dateAdded: now.addingTimeInterval(-3600)),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, dateAdded: now.addingTimeInterval(-7200)),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, dateAdded: now)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let sorted = try await repo.getItemsSortedByDate(ascending: false)

        #expect(sorted.count == 3)
        #expect(sorted[0].item_natural_key == "item-3") // Newest
        #expect(sorted[1].item_natural_key == "item-1")
        #expect(sorted[2].item_natural_key == "item-2") // Oldest
    }

    @Test("Get items sorted by quantity ascending")
    func testGetItemsSortedByQuantityAscending() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 10.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let sorted = try await repo.getItemsSortedByQuantity(ascending: true)

        #expect(sorted.count == 3)
        #expect(sorted[0].quantity == 3.0)
        #expect(sorted[1].quantity == 7.0)
        #expect(sorted[2].quantity == 10.0)
    }

    @Test("Get items sorted by quantity descending")
    func testGetItemsSortedByQuantityDescending() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 10.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        let sorted = try await repo.getItemsSortedByQuantity(ascending: false)

        #expect(sorted.count == 3)
        #expect(sorted[0].quantity == 10.0)
        #expect(sorted[1].quantity == 7.0)
        #expect(sorted[2].quantity == 3.0)
    }

    // MARK: - Batch Operations Tests

    @Test("Add multiple items in batch")
    func testAddItemsBatch() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        let created = try await repo.addItems(items)

        #expect(created.count == 3)

        let allItems = try await repo.fetchAllItems()
        #expect(allItems.count == 3)
    }

    @Test("Delete multiple items by IDs")
    func testDeleteItemsByIds() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0)
        ]

        var createdIds: [UUID] = []
        for item in items {
            let created = try await repo.createItem(item)
            createdIds.append(created.id)
        }

        // Delete first two items
        try await repo.deleteItems(ids: [createdIds[0], createdIds[1]])

        let remaining = try await repo.fetchAllItems()
        #expect(remaining.count == 1)
        #expect(remaining[0].item_natural_key == "item-3")
    }

    @Test("Delete all items for specific store")
    func testDeleteItemsForStore() async throws {
        let repo = createRepository()

        let items = [
            ItemShoppingModel(item_natural_key: "item-1", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-2", quantity: 3.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "item-3", quantity: 7.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "item-4", quantity: 2.0, store: "Olympic Color")
        ]

        for item in items {
            _ = try await repo.createItem(item)
        }

        try await repo.deleteItems(forStore: "Frantz Art Glass")

        let remaining = try await repo.fetchAllItems()
        #expect(remaining.count == 2)
        #expect(remaining.allSatisfy { $0.store == "Olympic Color" })
    }

    // MARK: - Edge Cases and Error Handling Tests

    @Test("Handle zero quantity")
    func testHandleZeroQuantity() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 0.0
        )

        do {
            _ = try await repo.createItem(item)
            Issue.record("Expected error for zero quantity")
        } catch {
            // Zero quantity should be invalid
            #expect(error is MockShoppingListRepositoryError)
        }
    }

    @Test("Handle negative quantity")
    func testHandleNegativeQuantity() async throws {
        let repo = createRepository()

        // Model init should clamp negative to 0, making it invalid
        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: -5.0
        )

        #expect(item.quantity == 0.0) // Model clamps to 0

        do {
            _ = try await repo.createItem(item)
            Issue.record("Expected error for negative (clamped to 0) quantity")
        } catch {
            #expect(error is MockShoppingListRepositoryError)
        }
    }

    @Test("Handle whitespace in natural key")
    func testHandleWhitespaceInNaturalKey() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "  bullseye-001-0  ",
            quantity: 5.0
        )

        let created = try await repo.createItem(item)

        // Model should trim whitespace
        #expect(created.item_natural_key == "bullseye-001-0")
    }

    @Test("Handle empty store name")
    func testHandleEmptyStoreName() async throws {
        let repo = createRepository()

        let item = ItemShoppingModel(
            item_natural_key: "bullseye-001-0",
            quantity: 5.0,
            store: ""
        )

        let created = try await repo.createItem(item)

        // Empty string should be treated as nil or empty
        #expect(created.store == "" || created.store == nil)
    }

    @Test("Concurrent operations are thread-safe")
    func testConcurrentOperations() async throws {
        let repo = createRepository()

        // Create multiple items concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let item = ItemShoppingModel(
                        item_natural_key: "concurrent-item-\(i)",
                        quantity: Double(i)
                    )
                    _ = try? await repo.createItem(item)
                }
            }
        }

        let allItems = try await repo.fetchAllItems()
        #expect(allItems.count == 10)
    }
}
