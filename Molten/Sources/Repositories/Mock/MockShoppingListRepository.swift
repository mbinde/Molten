//
//  MockShoppingListRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Mock implementation of ShoppingListRepository for testing
/// Provides in-memory storage for shopping list items with realistic behavior
class MockShoppingListRepository: @unchecked Sendable, ShoppingListRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var items: [UUID: ItemShoppingModel] = [:] // id -> ItemShoppingModel
    nonisolated(unsafe) private var itemsByNaturalKey: [String: UUID] = [:] // item_natural_key -> id
    private let queue = DispatchQueue(label: "mock.shoppinglist.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    nonisolated(unsafe) var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    nonisolated(unsafe) var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    nonisolated(unsafe) var failureProbability: Double = 0.1

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.items.removeAll()
            self.itemsByNaturalKey.removeAll()
        }
    }

    /// Get count of stored items (for testing)
    nonisolated func getStoredItemsCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.items.count)
            }
        }
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testItems = [
            ItemShoppingModel(item_natural_key: "cim-874-0", quantity: 5.0, store: "Frantz Art Glass"),
            ItemShoppingModel(item_natural_key: "bullseye-001-0", quantity: 10.0, store: "Olympic Color"),
            ItemShoppingModel(item_natural_key: "spectrum-96-0", quantity: 3.0, store: nil)
        ]

        for item in testItems {
            _ = try await createItem(item)
        }
    }

    // MARK: - Basic CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allItems = Array(self.items.values)
                        .sorted { $0.dateAdded < $1.dateAdded }
                    continuation.resume(returning: allItems)
                }
            }
        }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var allItems = Array(self.items.values)

                    if let predicate = predicate {
                        allItems = (allItems as NSArray).filtered(using: predicate) as? [ItemShoppingModel] ?? []
                    }

                    allItems.sort { $0.dateAdded < $1.dateAdded }
                    continuation.resume(returning: allItems)
                }
            }
        }
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[id])
                }
            }
        }
    }

    func fetchItem(forItem item_natural_key: String) async throws -> ItemShoppingModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    // Find first item with matching natural key
                    // Note: If multiple items exist (different stores), returns the first one
                    let matchingItem = self.items.values.first { $0.item_natural_key == item_natural_key }
                    continuation.resume(returning: matchingItem)
                }
            }
        }
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let storeItems = self.items.values.filter { item in
                        item.store?.lowercased() == store.lowercased()
                    }.sorted { $0.dateAdded < $1.dateAdded }

                    continuation.resume(returning: Array(storeItems))
                }
            }
        }
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await simulateOperation {
            guard item.isValid else {
                throw MockShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
            }

            // Check if item already exists with same natural key AND store
            let existing = await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItem = self.items.values.first { existingItem in
                        existingItem.item_natural_key == item.item_natural_key &&
                        existingItem.store == item.store
                    }
                    continuation.resume(returning: matchingItem)
                }
            }

            if existing != nil {
                throw MockShoppingListRepositoryError.itemAlreadyExists(item.item_natural_key)
            }

            // Create new item
            let newItem = ItemShoppingModel(
                id: item.id,
                item_natural_key: item.item_natural_key,
                quantity: item.quantity,
                store: item.store,
                type: item.type,
                subtype: item.subtype,
                subsubtype: item.subsubtype,
                dateAdded: item.dateAdded
            )

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items[newItem.id] = newItem
                    // Don't update itemsByNaturalKey - deprecated for shopping list
                    continuation.resume()
                }
            }

            return newItem
        }
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await simulateOperation {
            guard item.isValid else {
                throw MockShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
            }

            let existing = await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[item.id])
                }
            }

            guard existing != nil else {
                throw MockShoppingListRepositoryError.itemNotFound(item.id.uuidString)
            }

            let updatedItem = ItemShoppingModel(
                id: item.id,
                item_natural_key: item.item_natural_key,
                quantity: item.quantity,
                store: item.store,
                type: item.type,
                subtype: item.subtype,
                subsubtype: item.subsubtype,
                dateAdded: item.dateAdded
            )

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items[updatedItem.id] = updatedItem
                    self.itemsByNaturalKey[updatedItem.item_natural_key] = updatedItem.id
                    continuation.resume()
                }
            }

            return updatedItem
        }
    }

    func deleteItem(id: UUID) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items.removeValue(forKey: id)
                    continuation.resume()
                }
            }
        }
    }

    func deleteItem(forItem item_natural_key: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Delete ALL items with matching natural key (all stores)
                    let idsToDelete = self.items.values
                        .filter { $0.item_natural_key == item_natural_key }
                        .map { $0.id }

                    for id in idsToDelete {
                        self.items.removeValue(forKey: id)
                    }
                    continuation.resume()
                }
            }
        }
    }

    func deleteAllItems() async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items.removeAll()
                    self.itemsByNaturalKey.removeAll()
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Quantity Operations

    func updateQuantity(_ quantity: Double, forItem item_natural_key: String) async throws -> ItemShoppingModel {
        return try await simulateOperation {
            // Find first item with matching natural key
            guard let existingItem = await withCheckedContinuation({ continuation in
                self.queue.async {
                    let matchingItem = self.items.values.first { $0.item_natural_key == item_natural_key }
                    continuation.resume(returning: matchingItem)
                }
            }) else {
                throw MockShoppingListRepositoryError.itemNotFound(item_natural_key)
            }

            let updatedItem = existingItem.withQuantity(quantity)

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items[updatedItem.id] = updatedItem
                    continuation.resume()
                }
            }

            return updatedItem
        }
    }

    func addQuantity(_ quantity: Double, toItem item_natural_key: String, store: String?) async throws -> ItemShoppingModel {
        return try await simulateOperation {
            // Matching logic:
            // - If store is nil: Find ANY item with matching natural key (don't care about store)
            // - If store is not nil: Find item with matching natural key AND matching store
            let existingItem = await withCheckedContinuation({ continuation in
                self.queue.async {
                    let matchingItem: ItemShoppingModel?
                    if store == nil {
                        // When store is nil, match any item with this natural key
                        matchingItem = self.items.values.first { item in
                            item.item_natural_key == item_natural_key
                        }
                    } else {
                        // When store is provided, match both natural key AND store
                        matchingItem = self.items.values.first { item in
                            item.item_natural_key == item_natural_key &&
                            item.store == store
                        }
                    }
                    continuation.resume(returning: matchingItem)
                }
            })

            if let existingItem = existingItem {
                // Update existing item - quantity increases, store remains unchanged
                let newQuantity = existingItem.quantity + quantity
                let updatedItem = existingItem.withQuantity(newQuantity)

                await withCheckedContinuation { continuation in
                    self.queue.async(flags: .barrier) {
                        self.items[updatedItem.id] = updatedItem
                        continuation.resume()
                    }
                }

                return updatedItem
            } else {
                // Create new item (no matching item found)
                let newItem = ItemShoppingModel(
                    item_natural_key: item_natural_key,
                    quantity: quantity,
                    store: store
                )

                await withCheckedContinuation { continuation in
                    self.queue.async(flags: .barrier) {
                        self.items[newItem.id] = newItem
                        // NOTE: Don't update itemsByNaturalKey since multiple items
                        // can have the same natural key (different stores)
                        continuation.resume()
                    }
                }

                return newItem
            }
        }
    }

    // MARK: - Store Operations

    func updateStore(_ store: String?, forItem item_natural_key: String) async throws -> ItemShoppingModel {
        return try await simulateOperation {
            // Find first item with matching natural key
            guard let existingItem = await withCheckedContinuation({ continuation in
                self.queue.async {
                    let matchingItem = self.items.values.first { $0.item_natural_key == item_natural_key }
                    continuation.resume(returning: matchingItem)
                }
            }) else {
                throw MockShoppingListRepositoryError.itemNotFound(item_natural_key)
            }

            let updatedItem = existingItem.withStore(store)

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items[updatedItem.id] = updatedItem
                    continuation.resume()
                }
            }

            return updatedItem
        }
    }

    func getDistinctStores() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let stores = Set(self.items.values.compactMap { $0.store })
                    continuation.resume(returning: stores.sorted())
                }
            }
        }
    }

    func getItemCountByStore() async throws -> [String: Int] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var counts: [String: Int] = [:]
                    for item in self.items.values {
                        if let store = item.store {
                            counts[store, default: 0] += 1
                        }
                    }
                    continuation.resume(returning: counts)
                }
            }
        }
    }

    // MARK: - Discovery Operations

    func isItemInList(_ item_natural_key: String) async throws -> Bool {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let exists = self.items.values.contains { $0.item_natural_key == item_natural_key }
                    continuation.resume(returning: exists)
                }
            }
        }
    }

    func getItemCount() async throws -> Int {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items.count)
                }
            }
        }
    }

    func getItemCount(forStore store: String) async throws -> Int {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let count = self.items.values.filter { item in
                        item.store?.lowercased() == store.lowercased()
                    }.count
                    continuation.resume(returning: count)
                }
            }
        }
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let sorted = self.items.values.sorted { lhs, rhs in
                        ascending ? lhs.dateAdded < rhs.dateAdded : lhs.dateAdded > rhs.dateAdded
                    }
                    continuation.resume(returning: Array(sorted))
                }
            }
        }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let sorted = self.items.values.sorted { lhs, rhs in
                        ascending ? lhs.quantity < rhs.quantity : lhs.quantity > rhs.quantity
                    }
                    continuation.resume(returning: Array(sorted))
                }
            }
        }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        return try await simulateOperation {
            var createdItems: [ItemShoppingModel] = []

            for item in items {
                guard item.isValid else {
                    throw MockShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
                }

                // Check if item exists with same natural key AND store
                let existing = await withCheckedContinuation { continuation in
                    self.queue.async {
                        let matchingItem = self.items.values.first { existingItem in
                            existingItem.item_natural_key == item.item_natural_key &&
                            existingItem.store == item.store
                        }
                        continuation.resume(returning: matchingItem)
                    }
                }

                if existing != nil {
                    throw MockShoppingListRepositoryError.itemAlreadyExists(item.item_natural_key)
                }

                let newItem = ItemShoppingModel(
                    id: item.id,
                    item_natural_key: item.item_natural_key,
                    quantity: item.quantity,
                    store: item.store,
                    type: item.type,
                    subtype: item.subtype,
                    subsubtype: item.subsubtype,
                    dateAdded: item.dateAdded
                )

                await withCheckedContinuation { continuation in
                    self.queue.async(flags: .barrier) {
                        self.items[newItem.id] = newItem
                        // Don't update itemsByNaturalKey - deprecated for shopping list
                        continuation.resume()
                    }
                }

                createdItems.append(newItem)
            }

            return createdItems
        }
    }

    func deleteItems(ids: [UUID]) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for id in ids {
                        self.items.removeValue(forKey: id)
                    }
                    continuation.resume()
                }
            }
        }
    }

    func deleteItems(forStore store: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let idsToDelete = self.items.values
                        .filter { $0.store?.lowercased() == store.lowercased() }
                        .map { $0.id }

                    for id in idsToDelete {
                        self.items.removeValue(forKey: id)
                    }

                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    nonisolated private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockShoppingListRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.05) // 10-50ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }
}

// MARK: - Mock Repository Errors

enum MockShoppingListRepositoryError: Error, LocalizedError {
    case invalidData(String)
    case itemAlreadyExists(String)
    case itemNotFound(String)
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid shopping list item data: \(message)"
        case .itemAlreadyExists(let itemKey):
            return "Shopping list item already exists: \(itemKey)"
        case .itemNotFound(let identifier):
            return "Shopping list item not found: \(identifier)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}
