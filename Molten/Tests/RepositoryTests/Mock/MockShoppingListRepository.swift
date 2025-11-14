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
final class MockShoppingListRepository: ShoppingListRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [UUID: ItemShoppingModel] = [:]

    // MARK: - CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        return Array(items.values).sorted { $0.dateAdded > $1.dateAdded }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        // For simplicity, ignore predicate filtering in mock
        return try await fetchAllItems()
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return items[id]
    }

    func fetchItem(forItem item_stable_id: String) async throws -> ItemShoppingModel? {
        return items.values.first { $0.item_stable_id == item_stable_id }
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        return items.values
            .filter { $0.store == store }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        items[item.id] = item
        return item
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        guard items[item.id] != nil else {
            throw NSError(domain: "MockShoppingListRepository", code: 404)
        }
        items[item.id] = item
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
            items.removeValue(forKey: item.id)
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

        let updated = ItemShoppingModel(
            id: existing.id,
            item_stable_id: existing.item_stable_id,
            quantity: quantity,
            store: existing.store,
            type: existing.type,
            subtype: existing.subtype,
            subsubtype: existing.subsubtype,
            dateAdded: existing.dateAdded
        )

        items[existing.id] = updated
        return updated
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, store: String?) async throws -> ItemShoppingModel {
        if let existing = try await fetchItem(forItem: item_stable_id) {
            let newQuantity = existing.quantity + quantity
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

        let updated = ItemShoppingModel(
            id: existing.id,
            item_stable_id: existing.item_stable_id,
            quantity: existing.quantity,
            store: store,
            type: existing.type,
            subtype: existing.subtype,
            subsubtype: existing.subsubtype,
            dateAdded: existing.dateAdded
        )

        items[existing.id] = updated
        return updated
    }

    func getDistinctStores() async throws -> [String] {
        let stores = Set(items.values.compactMap { $0.store })
        return stores.sorted()
    }

    func getItemCountByStore() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items.values {
            if let store = item.store {
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
        return items.values.filter { $0.store == store }.count
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        if ascending {
            return items.values.sorted { $0.dateAdded < $1.dateAdded }
        } else {
            return items.values.sorted { $0.dateAdded > $1.dateAdded }
        }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        if ascending {
            return items.values.sorted { $0.quantity < $1.quantity }
        } else {
            return items.values.sorted { $0.quantity > $1.quantity }
        }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        for item in items {
            self.items[item.id] = item
        }
        return items
    }

    func deleteItems(ids: [UUID]) async throws {
        for id in ids {
            items.removeValue(forKey: id)
        }
    }

    func deleteItems(forStore store: String) async throws {
        items = items.filter { $0.value.store != store }
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
