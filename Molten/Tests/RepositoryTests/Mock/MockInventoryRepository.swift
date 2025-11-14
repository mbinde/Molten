//
//  MockInventoryRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of InventoryRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of InventoryRepository for testing
/// Stores inventory in memory using a dictionary
final class MockInventoryRepository: InventoryRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var inventory: [UUID: InventoryModel] = [:] // Key: id

    // MARK: - CRUD Operations

    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(inventory.values)
    }

    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return inventory[id]
    }

    func fetchInventory(forItem item_stable_id: String) async throws -> [InventoryModel] {
        let inventoryArray = Array(inventory.values)
        var result: [InventoryModel] = []
        for inv in inventoryArray {
            let invItemId = await inv.item_stable_id
            if invItemId == item_stable_id {
                result.append(inv)
            }
        }
        return result
    }

    func fetchInventory(forItem item_stable_id: String, type: String) async throws -> [InventoryModel] {
        let inventoryArray = Array(inventory.values)
        var result: [InventoryModel] = []
        for inv in inventoryArray {
            let invItemId = await inv.item_stable_id
            let invType = await inv.type
            if invItemId == item_stable_id && invType == type {
                result.append(inv)
            }
        }
        return result
    }

    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        let id = await inventory.id
        self.inventory[id] = inventory
        return inventory
    }

    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        for inventory in inventories {
            let id = await inventory.id
            self.inventory[id] = inventory
        }
        return inventories
    }

    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        let id = await inventory.id
        guard self.inventory[id] != nil else {
            throw NSError(domain: "MockInventoryRepository", code: 404)
        }
        self.inventory[id] = inventory
        return inventory
    }

    func deleteInventory(id: UUID) async throws {
        inventory.removeValue(forKey: id)
    }

    func deleteInventory(forItem item_stable_id: String) async throws {
        let inventoryArray = Array(inventory)
        for (id, inv) in inventoryArray {
            let invItemId = await inv.item_stable_id
            if invItemId == item_stable_id {
                inventory.removeValue(forKey: id)
            }
        }
    }

    func deleteInventory(forItem item_stable_id: String, type: String) async throws {
        let inventoryArray = Array(inventory)
        for (id, inv) in inventoryArray {
            let invItemId = await inv.item_stable_id
            let invType = await inv.type
            if invItemId == item_stable_id && invType == type {
                inventory.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Quantity Operations

    func getTotalQuantity(forItem item_stable_id: String) async throws -> Double {
        let items = try await fetchInventory(forItem: item_stable_id)
        var total = 0.0
        for inv in items {
            let qty = await inv.quantity
            total += qty
        }
        return total
    }

    func getTotalQuantity(forItem item_stable_id: String, type: String) async throws -> Double {
        let items = try await fetchInventory(forItem: item_stable_id, type: type)
        var total = 0.0
        for inv in items {
            let qty = await inv.quantity
            total += qty
        }
        return total
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, type: String) async throws -> InventoryModel {
        let existing = try await fetchInventory(forItem: item_stable_id, type: type).first

        if let existing = existing {
            let existingQty = await existing.quantity
            let existingId = await existing.id
            let existingLocation = await existing.location
            let updated = InventoryModel(
                id: existingId,
                item_stable_id: item_stable_id,
                quantity: existingQty + quantity,
                type: type,
                location: existingLocation
            )
            return try await updateInventory(updated)
        } else {
            let new = InventoryModel(
                id: UUID(),
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: type,
                location: nil
            )
            return try await createInventory(new)
        }
    }

    func subtractQuantity(_ quantity: Double, fromItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        guard let existing = try await fetchInventory(forItem: item_stable_id, type: type).first else {
            throw NSError(domain: "MockInventoryRepository", code: 404)
        }

        let existingQty = await existing.quantity
        let newQty = existingQty - quantity

        if newQty <= 0 {
            let existingId = await existing.id
            try await deleteInventory(id: existingId)
            return nil
        } else {
            let existingId = await existing.id
            let existingLocation = await existing.location
            let updated = InventoryModel(
                id: existingId,
                item_stable_id: item_stable_id,
                quantity: newQty,
                type: type,
                location: existingLocation
            )
            return try await updateInventory(updated)
        }
    }

    func setQuantity(_ quantity: Double, forItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        if quantity <= 0 {
            try await deleteInventory(forItem: item_stable_id, type: type)
            return nil
        }

        let existing = try await fetchInventory(forItem: item_stable_id, type: type).first

        if let existing = existing {
            let existingId = await existing.id
            let existingLocation = await existing.location
            let updated = InventoryModel(
                id: existingId,
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: type,
                location: existingLocation
            )
            return try await updateInventory(updated)
        } else {
            let new = InventoryModel(
                id: UUID(),
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: type,
                location: nil
            )
            return try await createInventory(new)
        }
    }

    // MARK: - Discovery Operations

    func getDistinctTypes() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        var types: Set<String> = []
        for inv in inventoryArray {
            let type = await inv.type
            types.insert(type)
        }
        return types.sorted()
    }

    func getItemsWithInventory() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        var items: Set<String> = []
        for inv in inventoryArray {
            let itemId = await inv.item_stable_id
            items.insert(itemId)
        }
        return items.sorted()
    }

    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        var items: Set<String> = []
        for inv in inventoryArray {
            let invType = await inv.type
            if invType == type {
                let itemId = await inv.item_stable_id
                items.insert(itemId)
            }
        }
        return items.sorted()
    }

    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_stable_id: String, type: String, quantity: Double)] {
        let inventoryArray = Array(inventory.values)
        var results: [(item_stable_id: String, type: String, quantity: Double)] = []
        for inv in inventoryArray {
            let qty = await inv.quantity
            if qty > 0 && qty < threshold {
                let itemId = await inv.item_stable_id
                let type = await inv.type
                results.append((item_stable_id: itemId, type: type, quantity: qty))
            }
        }
        return results
    }

    func getItemsWithZeroInventory() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        var items: Set<String> = []
        for inv in inventoryArray {
            let qty = await inv.quantity
            if qty == 0 {
                let itemId = await inv.item_stable_id
                items.insert(itemId)
            }
        }
        return items.sorted()
    }

    // MARK: - Aggregation Operations

    func getInventorySummary() async throws -> [InventorySummaryModel] {
        var summaries: [String: [InventoryModel]] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            let itemId = await inv.item_stable_id
            if summaries[itemId] == nil {
                summaries[itemId] = []
            }
            summaries[itemId]?.append(inv)
        }

        let summaryArray = summaries.map { (key, value) in
            InventorySummaryModel(item_stable_id: key, inventories: value)
        }
        return summaryArray.sorted { (a, b) in
            a.item_stable_id < b.item_stable_id
        }
    }

    func getInventorySummary(forItem item_stable_id: String) async throws -> InventorySummaryModel? {
        let items = try await fetchInventory(forItem: item_stable_id)
        guard !items.isEmpty else { return nil }

        return InventorySummaryModel(item_stable_id: item_stable_id, inventories: items)
    }

    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        var values: [String: Double] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            let itemId = await inv.item_stable_id
            let qty = await inv.quantity
            values[itemId] = (values[itemId] ?? 0) + (qty * defaultPricePerUnit)
        }

        return values
    }

    // MARK: - Location Operations

    func fetchInventory(atLocation location: String) async throws -> [InventoryModel] {
        let inventoryArray = Array(inventory.values)
        var filtered: [InventoryModel] = []
        for inv in inventoryArray {
            let invLocation = await inv.location
            if invLocation == location {
                filtered.append(inv)
            }
        }
        return filtered
    }

    func getDistinctLocations() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        var locations: Set<String> = []
        for inv in inventoryArray {
            let location = await inv.location
            if let location = location {
                locations.insert(location)
            }
        }
        return locations.sorted()
    }

    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let locations = try await getDistinctLocations()
        return locations.filter { $0.hasPrefix(prefix) }
    }

    func getLocationUtilization(for location: String) async throws -> [String: Double] {
        let items = try await fetchInventory(atLocation: location)
        var utilization: [String: Double] = [:]

        for inv in items {
            let itemId = await inv.item_stable_id
            let qty = await inv.quantity
            utilization[itemId] = (utilization[itemId] ?? 0) + qty
        }

        return utilization
    }

    func getAllLocationUtilization() async throws -> [String: Double] {
        var utilization: [String: Double] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            let location = await inv.location
            let qty = await inv.quantity
            if let location = location {
                utilization[location] = (utilization[location] ?? 0) + qty
            }
        }

        return utilization
    }

    // MARK: - Test Helpers

    /// Get count of stored inventory records (test helper)
    func getInventoryCount() async -> Int {
        return inventory.count
    }

    /// Clear all inventory (test helper)
    func clearAll() async {
        inventory.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        inventory.removeAll()
    }
}
