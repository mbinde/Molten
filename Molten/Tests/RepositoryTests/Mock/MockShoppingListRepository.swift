//
//  MockShoppingListRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of ShoppingListRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of ShoppingListRepository for testing
/// Stores shopping list items in memory using a dictionary
@MainActor
final class MockShoppingListRepository: ShoppingListRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [UUID: ItemShoppingModel] = [:]

    // MARK: - CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        let itemsArray = Array(items.values)
        // ItemShoppingModel properties are synchronous, no await needed
        return itemsArray.sorted { $0.dateAdded > $1.dateAdded }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        // For simplicity, ignore predicate filtering in mock
        return try await fetchAllItems()
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return items[id]
    }

    func fetchItem(forItem item_stable_id: String) async throws -> ItemShoppingModel? {
        let itemsArray = Array(items.values)
        // ItemShoppingModel properties are synchronous, no await needed
        return itemsArray.first { $0.item_stable_id == item_stable_id }
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        let itemsArray = Array(items.values)
        // ItemShoppingModel properties are synchronous, no await needed
        let filtered = itemsArray.filter { $0.store == store }
        return filtered.sorted { $0.dateAdded > $1.dateAdded }
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        let itemId = await item.id
        items[itemId] = item
        return item
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        let itemId = await item.id
        guard items[itemId] != nil else {
            throw NSError(domain: "MockShoppingListRepository", code: 404)
        }
        items[itemId] = item
        return item
    }

    func deleteItem(id: UUID) async throws {
        guard items[id] != nil else {
            throw NSError(domain: "MockShoppingListRepository", code: 404)
        }
        items.removeValue(forKey: id)
    }

    func deleteItem(forItem item_stable_id: String) async throws {
        if let item = try await fetchItem(forItem: item_stable_id) {
            let itemId = await item.id; items.removeValue(forKey: itemId)
        }
    }

    func deleteAllItems() async throws {
        items.removeAll()
    }

    // MARK: - Quantity Operations

    func updateQuantity(_ quantity: Double, forItem item_stable_id: String) async throws -> ItemShoppingModel {
        guard let existing = try await fetchItem(forItem: item_stable_id) else {
            throw NSError(domain: "MockShoppingListRepository", code: 404)
        }

        let existingId = await existing.id
        let existingItemId = await existing.item_stable_id
        let existingStore = await existing.store
        let existingType = await existing.type
        let existingSubtype = await existing.subtype
        let existingSubsubtype = await existing.subsubtype
        let existingDate = await existing.dateAdded

        let updated = ItemShoppingModel(
            id: existingId,
            item_stable_id: existingItemId,
            quantity: quantity,
            store: existingStore,
            type: existingType,
            subtype: existingSubtype,
            subsubtype: existingSubsubtype,
            dateAdded: existingDate
        )

        items[existingId] = updated
        return updated
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, store: String?) async throws -> ItemShoppingModel {
        if let existing = try await fetchItem(forItem: item_stable_id) {
            let existingQty = await existing.quantity
            let newQuantity = existingQty + quantity
            return try await updateQuantity(newQuantity, forItem: item_stable_id)
        } else {
            let newItem = ItemShoppingModel(
                item_stable_id: item_stable_id,
                quantity: quantity,
                store: store
            )
            return try await createItem(newItem)
        }
    }

    // MARK: - Store Operations

    func updateStore(_ store: String?, forItem item_stable_id: String) async throws -> ItemShoppingModel {
        guard let existing = try await fetchItem(forItem: item_stable_id) else {
            throw NSError(domain: "MockShoppingListRepository", code: 404)
        }

        let existingId = await existing.id
        let existingItemId = await existing.item_stable_id
        let existingQty = await existing.quantity
        let existingType = await existing.type
        let existingSubtype = await existing.subtype
        let existingSubsubtype = await existing.subsubtype
        let existingDate = await existing.dateAdded

        let updated = ItemShoppingModel(
            id: existingId,
            item_stable_id: existingItemId,
            quantity: existingQty,
            store: store,
            type: existingType,
            subtype: existingSubtype,
            subsubtype: existingSubsubtype,
            dateAdded: existingDate
        )

        items[existingId] = updated
        return updated
    }

    func getDistinctStores() async throws -> [String] {
        let itemsArray = Array(items.values)
        var stores: Set<String> = []
        for item in itemsArray {
            let store = await item.store
            if let store = store {
                stores.insert(store)
            }
        }
        return stores.sorted()
    }

    func getItemCountByStore() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let itemsArray = Array(items.values)
        for item in itemsArray {
            let store = await item.store
            if let store = store {
                counts[store, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Discovery Operations

    func isItemInList(_ item_stable_id: String) async throws -> Bool {
        return try await fetchItem(forItem: item_stable_id) != nil
    }

    func getItemCount() async throws -> Int {
        return items.count
    }

    func getItemCount(forStore store: String) async throws -> Int {
        var count = 0
        for item in items.values {
            let itemStore = await item.store
            if itemStore == store {
                count += 1
            }
        }
        return count
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        let itemsArray = Array(items.values)
        // ItemShoppingModel properties are synchronous, no await needed
        return itemsArray.sorted { a, b in
            ascending ? a.dateAdded < b.dateAdded : a.dateAdded > b.dateAdded
        }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        let itemsArray = Array(items.values)
        // ItemShoppingModel properties are synchronous, no await needed
        return itemsArray.sorted { a, b in
            ascending ? a.quantity < b.quantity : a.quantity > b.quantity
        }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        for item in items {
            let itemId = await item.id; self.items[itemId] = item
        }
        return items
    }

    func deleteItems(ids: [UUID]) async throws {
        for id in ids {
            items.removeValue(forKey: id)
        }
    }

    func deleteItems(forStore store: String) async throws {
        let itemsArray = Array(items)
        var newItems: [UUID: ItemShoppingModel] = [:]
        for (key, value) in itemsArray {
            let itemStore = await value.store
            if itemStore != store {
                newItems[key] = value
            }
        }
        items = newItems
    }

    // MARK: - Test Helpers

    /// Get count of stored items (test helper)
    func getStoredItemCount() async -> Int {
        return items.count
    }

    /// Clear all items (test helper)
    func clearAll() async {
        items.removeAll()
    }
}
