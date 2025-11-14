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
        return minimums.values.filter { $0.item_stable_id == item_stable_id }
    }

    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel] {
        return minimums.values.filter { $0.store == store }
    }

    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let key = makeKey(item: minimum.item_stable_id, type: minimum.type)
        minimums[key] = minimum
        return minimum
    }

    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        for minimum in minimums {
            let key = makeKey(item: minimum.item_stable_id, type: minimum.type)
            self.minimums[key] = minimum
        }
        return minimums
    }

    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let key = makeKey(item: minimum.item_stable_id, type: minimum.type)
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
        minimums = minimums.filter { $0.value.item_stable_id != item_stable_id }
    }

    func deleteMinimums(forStore store: String) async throws {
        minimums = minimums.filter { $0.value.store != store }
    }

    // MARK: - Shopping List Operations

    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel] {
        let storeMinimums = try await fetchMinimums(forStore: store)
        var shoppingList: [ShoppingListItemModel] = []

        for minimum in storeMinimums {
            let currentQty = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0
            if currentQty < minimum.quantity {
                let item = ShoppingListItemModel(
                    item_stable_id: minimum.item_stable_id,
                    type: minimum.type,
                    currentQuantity: currentQty,
                    minimumQuantity: minimum.quantity,
                    store: store
                )
                shoppingList.append(item)
            }
        }

        return shoppingList.sorted()
    }

    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]] {
        let allStores = Set(minimums.values.map { $0.store })
        var result: [String: [ShoppingListItemModel]] = [:]

        for store in allStores {
            result[store] = try await generateShoppingList(forStore: store, currentInventory: currentInventory)
        }

        return result
    }

    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel] {
        var lowStock: [LowStockItemModel] = []

        for minimum in minimums.values {
            let currentQty = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0
            if currentQty < minimum.quantity {
                let item = LowStockItemModel(
                    item_stable_id: minimum.item_stable_id,
                    type: minimum.type,
                    currentQuantity: currentQty,
                    minimumQuantity: minimum.quantity,
                    store: minimum.store
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
        let stores = Set(minimums.values.map { $0.store })
        return stores.sorted()
    }

    func getStores(withPrefix prefix: String) async throws -> [String] {
        let stores = Set(minimums.values.map { $0.store })
        return stores.filter { $0.hasPrefix(prefix) }.sorted()
    }

    func getStoreUtilization() async throws -> [String: Int] {
        var utilization: [String: Int] = [:]
        for minimum in minimums.values {
            utilization[minimum.store, default: 0] += 1
        }
        return utilization
    }

    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws {
        for (key, minimum) in minimums where minimum.store == oldStoreName {
            let updated = ItemMinimumModel(
                id: minimum.id,
                item_stable_id: minimum.item_stable_id,
                quantity: minimum.quantity,
                type: minimum.type,
                store: newStoreName
            )
            minimums[key] = updated
        }
    }

    // MARK: - Analytics Operations

    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics {
        let allMinimums = Array(minimums.values)
        return MinimumQuantityStatistics(minimums: allMinimums)
    }

    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel] {
        return minimums.values
            .sorted { $0.quantity > $1.quantity }
            .prefix(limit)
            .map { $0 }
    }

    func getMostCommonTypes() async throws -> [String: Int] {
        var typeCounts: [String: Int] = [:]
        for minimum in minimums.values {
            typeCounts[minimum.type, default: 0] += 1
        }
        return typeCounts
    }

    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel] {
        return minimums.values.filter { !validItemKeys.contains($0.item_stable_id) }
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
}
