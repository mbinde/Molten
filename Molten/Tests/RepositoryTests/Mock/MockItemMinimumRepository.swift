//
//  MockItemMinimumRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of ItemMinimumRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of ItemMinimumRepository for testing
/// Stores minimums in memory using a dictionary
final class MockItemMinimumRepository: ItemMinimumRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var minimums: [String: ItemMinimumModel] = [:] // Key: "item_stable_id-type"

    // MARK: - Helper Methods

    private func makeKey(item: String, type: String) -> String {
        return "\(item)-\(type)"
    }

    // MARK: - CRUD Operations

    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(minimums.values)
    }

    func fetchMinimum(forItem item_stable_id: String, type: String) async throws -> ItemMinimumModel? {
        return minimums[makeKey(item: item_stable_id, type: type)]
    }

    func fetchMinimums(forItem item_stable_id: String) async throws -> [ItemMinimumModel] {
        let minimumsArray = Array(minimums.values)
        return minimumsArray.filter { (minimum: ItemMinimumModel) in
            let minItemId = minimum.item_stable_id
            return minItemId == item_stable_id
        }
    }

    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel] {
        let minimumsArray = Array(minimums.values)
        return minimumsArray.filter { (minimum: ItemMinimumModel) in
            let minStore = minimum.store
            return minStore == store
        }
    }

    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let itemId = minimum.item_stable_id
        let type = minimum.type
        let key = makeKey(item: itemId, type: type)
        minimums[key] = minimum
        return minimum
    }

    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        for minimum in minimums {
            let itemId = minimum.item_stable_id
            let type = minimum.type
            let key = makeKey(item: itemId, type: type)
            self.minimums[key] = minimum
        }
        return minimums
    }

    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let itemId = minimum.item_stable_id
        let type = minimum.type
        let key = makeKey(item: itemId, type: type)
        guard minimums[key] != nil else {
            throw NSError(domain: "MockItemMinimumRepository", code: 404)
        }
        minimums[key] = minimum
        return minimum
    }

    func deleteMinimum(forItem item_stable_id: String, type: String) async throws {
        minimums.removeValue(forKey: makeKey(item: item_stable_id, type: type))
    }

    func deleteMinimums(forItem item_stable_id: String) async throws {
        let minimumsArray = Array(minimums)
        for (key, minimum) in minimumsArray {
            let minItemId = minimum.item_stable_id
            if minItemId == item_stable_id {
                minimums.removeValue(forKey: key)
            }
        }
    }

    func deleteMinimums(forStore store: String) async throws {
        let minimumsArray = Array(minimums)
        for (key, minimum) in minimumsArray {
            let minStore = minimum.store
            if minStore == store {
                minimums.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Shopping List Operations

    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel] {
        let storeMinimums = try await fetchMinimums(forStore: store)
        var shoppingList: [ShoppingListItemModel] = []

        for minimum in storeMinimums {
            let minItemId = minimum.item_stable_id
            let minType = minimum.type
            let minQty = minimum.quantity
            let currentQty = currentInventory[minItemId]?[minType] ?? 0.0
            if currentQty < minQty {
                let item = ShoppingListItemModel(
                    item_stable_id: minItemId,
                    type: minType,
                    currentQuantity: currentQty,
                    minimumQuantity: minQty,
                    store: store
                )
                shoppingList.append(item)
            }
        }

        return shoppingList.sorted()
    }

    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]] {
        let minimumsArray = Array(minimums.values)
        let allStores = Set(minimumsArray.map { (minimum: ItemMinimumModel) in
            let store = minimum.store
            return store
        })
        var result: [String: [ShoppingListItemModel]] = [:]

        for store in allStores {
            result[store] = try await generateShoppingList(forStore: store, currentInventory: currentInventory)
        }

        return result
    }

    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel] {
        var lowStock: [LowStockItemModel] = []

        let minimumsArray = Array(minimums.values)
        for minimum in minimumsArray {
            let minItemId = minimum.item_stable_id
            let minType = minimum.type
            let minQty = minimum.quantity
            let minStore = minimum.store
            let currentQty = currentInventory[minItemId]?[minType] ?? 0.0
            if currentQty < minQty {
                let item = LowStockItemModel(
                    item_stable_id: minItemId,
                    type: minType,
                    currentQuantity: currentQty,
                    minimumQuantity: minQty,
                    store: minStore
                )
                lowStock.append(item)
            }
        }

        return lowStock.sorted()
    }

    func setMinimumQuantity(_ quantity: Double, forItem item_stable_id: String, type: String, store: String) async throws -> ItemMinimumModel {
        let minimum = ItemMinimumModel(
            item_stable_id: item_stable_id,
            quantity: quantity,
            type: type,
            store: store
        )
        let key = makeKey(item: item_stable_id, type: type)
        minimums[key] = minimum
        return minimum
    }

    // MARK: - Store Management Operations

    func getDistinctStores() async throws -> [String] {
        let minimumsArray = Array(minimums.values)
        let stores = Set(minimumsArray.map { (minimum: ItemMinimumModel) in
            minimum.store
        })
        return stores.sorted()
    }

    func getStores(withPrefix prefix: String) async throws -> [String] {
        let minimumsArray = Array(minimums.values)
        let stores = Set(minimumsArray.map { (minimum: ItemMinimumModel) in
            minimum.store
        })
        return stores.filter { $0.hasPrefix(prefix) }.sorted()
    }

    func getStoreUtilization() async throws -> [String: Int] {
        var utilization: [String: Int] = [:]
        let minimumsArray = Array(minimums.values)
        for minimum in minimumsArray {
            let store = minimum.store
            utilization[store, default: 0] += 1
        }
        return utilization
    }

    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws {
        let minimumsArray = Array(minimums)
        for (key, minimum) in minimumsArray {
            // Extract values first to avoid actor isolation issues
            let minStore = minimum.store
            if minStore == oldStoreName {
                let minId = minimum.id
                let minItemId = minimum.item_stable_id
                let minQty = minimum.quantity
                let minType = minimum.type

                let updated = ItemMinimumModel(
                    id: minId,
                    item_stable_id: minItemId,
                    quantity: minQty,
                    type: minType,
                    store: newStoreName
                )
                minimums[key] = updated
            }
        }
    }

    // MARK: - Analytics Operations

    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics {
        let allMinimums = Array(minimums.values)
        return MinimumQuantityStatistics(minimums: allMinimums)
    }

    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel] {
        let minimumsArray = Array(minimums.values)
        return minimumsArray
            .sorted { (a: ItemMinimumModel, b: ItemMinimumModel) in
                let aQty = a.quantity
                let bQty = b.quantity
                return aQty > bQty
            }
            .prefix(limit)
            .map { $0 }
    }

    func getMostCommonTypes() async throws -> [String: Int] {
        var typeCounts: [String: Int] = [:]
        let minimumsArray = Array(minimums.values)
        for minimum in minimumsArray {
            let typeString = minimum.type
            typeCounts[typeString, default: 0] += 1
        }
        return typeCounts
    }

    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel] {
        let minimumsArray = Array(minimums.values)
        return minimumsArray.filter { (minimum: ItemMinimumModel) in
            let itemId = minimum.item_stable_id
            return !validItemKeys.contains(itemId)
        }
    }

    // MARK: - Test Helpers

    /// Get count of stored minimums (test helper)
    func getMinimumCount() async -> Int {
        return minimums.count
    }

    /// Clear all minimums (test helper)
    func clearAll() async {
        minimums.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        minimums.removeAll()
    }
}
