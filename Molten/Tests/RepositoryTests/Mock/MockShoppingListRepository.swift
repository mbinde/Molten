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
    private let lock = NSLock() // Protect concurrent access

    // MARK: - CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        let itemsArray = lock.withLock { Array(items.values) }
        // Extract-pair-sort-map pattern for async property
        var itemsWithDates: [(item: ItemShoppingModel, date: Date)] = []
        for item in itemsArray {
            let date = await item.dateAdded
            itemsWithDates.append((item, date))
        }
        itemsWithDates.sort { $0.date > $1.date }
        return itemsWithDates.map { $0.item }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        // For simplicity, ignore predicate filtering in mock
        return try await fetchAllItems()
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return lock.withLock { items[id] }
    }

    func fetchItem(forItem item_stable_id: String) async throws -> ItemShoppingModel? {
        let itemsArray = lock.withLock { Array(items.values) }
        // Use for loop to await actor-isolated property
        for item in itemsArray {
            let itemStableId = await item.item_stable_id
            if itemStableId == item_stable_id {
                return item
            }
        }
        return nil
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        let itemsArray = lock.withLock { Array(items.values) }
        // Filter by store
        var filtered: [ItemShoppingModel] = []
        for item in itemsArray {
            let itemStore = await item.store
            if itemStore == store {
                filtered.append(item)
            }
        }
        // Extract-pair-sort-map pattern for async property
        var itemsWithDates: [(item: ItemShoppingModel, date: Date)] = []
        for item in filtered {
            let date = await item.dateAdded
            itemsWithDates.append((item, date))
        }
        itemsWithDates.sort { $0.date > $1.date }
        return itemsWithDates.map { $0.item }
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        let itemId = await item.id
        let itemStableId = await item.item_stable_id
        let quantity = await item.quantity

        // Validate item data
        guard !itemStableId.isEmpty else {
            throw MockShoppingListRepositoryError.invalidData("Item stable ID cannot be empty")
        }

        guard quantity > 0 else {
            throw MockShoppingListRepositoryError.invalidData("Quantity must be greater than zero")
        }

        // Check for duplicates
        if try await fetchItem(forItem: itemStableId) != nil {
            throw MockShoppingListRepositoryError.itemAlreadyExists(itemStableId)
        }

        lock.withLock { items[itemId] = item }
        return item
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        let itemId = await item.id
        let exists = lock.withLock { items[itemId] != nil }
        guard exists else {
            throw MockShoppingListRepositoryError.itemNotFound
        }
        lock.withLock { items[itemId] = item }
        return item
    }

    func deleteItem(id: UUID) async throws {
        let exists = lock.withLock { items[id] != nil }
        guard exists else {
            throw MockShoppingListRepositoryError.itemNotFound
        }
        lock.withLock { items.removeValue(forKey: id) }
    }

    func deleteItem(forItem item_stable_id: String) async throws {
        if let item = try await fetchItem(forItem: item_stable_id) {
            let itemId = await item.id
            lock.withLock { items.removeValue(forKey: itemId) }
        }
    }

    func deleteAllItems() async throws {
        lock.withLock { items.removeAll() }
    }

    // MARK: - Quantity Operations

    func updateQuantity(_ quantity: Double, forItem item_stable_id: String) async throws -> ItemShoppingModel {
        guard let existing = try await fetchItem(forItem: item_stable_id) else {
            throw MockShoppingListRepositoryError.itemNotFound
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

        lock.withLock { items[existingId] = updated }
        return updated
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, store: String?) async throws -> ItemShoppingModel {
        // Look for existing item with BOTH same item_stable_id AND same store
        // Shopping list items are unique per (item_stable_id, store) tuple
        let itemsArray = lock.withLock { Array(items.values) }
        var existing: ItemShoppingModel? = nil
        for item in itemsArray {
            let itemStableId = await item.item_stable_id
            let itemStore = await item.store
            if itemStableId == item_stable_id && itemStore == store {
                existing = item
                break
            }
        }

        if let existing = existing {
            // Found exact match (same item + same store) - add to existing quantity
            let existingId = await existing.id
            let existingQty = await existing.quantity
            let existingItemId = await existing.item_stable_id
            let existingStore = await existing.store
            let existingType = await existing.type
            let existingSubtype = await existing.subtype
            let existingSubsubtype = await existing.subsubtype
            let existingDate = await existing.dateAdded

            let updated = ItemShoppingModel(
                id: existingId,
                item_stable_id: existingItemId,
                quantity: existingQty + quantity,
                store: existingStore,
                type: existingType,
                subtype: existingSubtype,
                subsubtype: existingSubsubtype,
                dateAdded: existingDate
            )

            lock.withLock { items[existingId] = updated }
            return updated
        } else {
            // No match found - create new item
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
            throw MockShoppingListRepositoryError.itemNotFound
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

        lock.withLock { items[existingId] = updated }
        return updated
    }

    func getDistinctStores() async throws -> [String] {
        let itemsArray = lock.withLock { Array(items.values) }
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
        let itemsArray = lock.withLock { Array(items.values) }
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
        return lock.withLock { items.count }
    }

    func getItemCount(forStore store: String) async throws -> Int {
        var count = 0
        let itemsArray = lock.withLock { Array(items.values) }
        for item in itemsArray {
            let itemStore = await item.store
            if itemStore == store {
                count += 1
            }
        }
        return count
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        let itemsArray = lock.withLock { Array(items.values) }
        // Extract-pair-sort-map pattern for async property
        var itemsWithDates: [(item: ItemShoppingModel, date: Date)] = []
        for item in itemsArray {
            let date = await item.dateAdded
            itemsWithDates.append((item, date))
        }
        itemsWithDates.sort { a, b in
            ascending ? a.date < b.date : a.date > b.date
        }
        return itemsWithDates.map { $0.item }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        let itemsArray = lock.withLock { Array(items.values) }
        // Extract-pair-sort-map pattern for async property
        var itemsWithQuantities: [(item: ItemShoppingModel, quantity: Double)] = []
        for item in itemsArray {
            let quantity = await item.quantity
            itemsWithQuantities.append((item, quantity))
        }
        itemsWithQuantities.sort { a, b in
            ascending ? a.quantity < b.quantity : a.quantity > b.quantity
        }
        return itemsWithQuantities.map { $0.item }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        for item in items {
            let itemId = await item.id
            lock.withLock { self.items[itemId] = item }
        }
        return items
    }

    func deleteItems(ids: [UUID]) async throws {
        lock.withLock {
            for id in ids {
                items.removeValue(forKey: id)
            }
        }
    }

    func deleteItems(forStore store: String) async throws {
        let itemsArray = lock.withLock { Array(items) }
        var newItems: [UUID: ItemShoppingModel] = [:]
        for (key, value) in itemsArray {
            let itemStore = await value.store
            if itemStore != store {
                newItems[key] = value
            }
        }
        lock.withLock { items = newItems }
    }

    // MARK: - Test Helpers

    /// Get count of stored items (test helper)
    func getStoredItemCount() async -> Int {
        return lock.withLock { items.count }
    }

    /// Clear all items (test helper)
    func clearAll() async {
        lock.withLock { items.removeAll() }
    }

    /// Clear all items (test helper - alternate name for compatibility)
    func clearAllData() {
        lock.withLock { items.removeAll() }
    }
}

// MARK: - Mock Errors

enum MockShoppingListRepositoryError: Error {
    case itemNotFound
    case invalidOperation
    case itemAlreadyExists(String)
    case invalidData(String)
}
