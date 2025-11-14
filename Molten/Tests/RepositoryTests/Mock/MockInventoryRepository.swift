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
        return inventoryArray.filter { (inv: InventoryModel) in
            let invItemId = inv.item_stable_id
            return invItemId == item_stable_id
        }
    }

    func fetchInventory(forItem item_stable_id: String, type: String) async throws -> [InventoryModel] {
        let inventoryArray = Array(inventory.values)
        return inventoryArray.filter { (inv: InventoryModel) in
            let invItemId = inv.item_stable_id
            let invType = inv.type
            return invItemId == item_stable_id && invType == type
        }
    }

    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        let id = inventory.id
        self.inventory[id] = inventory
        return inventory
    }

    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        for inventory in inventories {
            let id = inventory.id
            self.inventory[id] = inventory
        }
        return inventories
    }

    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        let id = inventory.id
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
            let invItemId = inv.item_stable_id
            if invItemId == item_stable_id {
                inventory.removeValue(forKey: id)
            }
        }
    }

    func deleteInventory(forItem item_stable_id: String, type: String) async throws {
        let inventoryArray = Array(inventory)
        for (id, inv) in inventoryArray {
            let invItemId = inv.item_stable_id
            let invType = inv.type
            if invItemId == item_stable_id && invType == type {
                inventory.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Quantity Operations

    func getTotalQuantity(forItem item_stable_id: String) async throws -> Double {
        let items = try await fetchInventory(forItem: item_stable_id)
        return items.reduce(0.0) { (sum, inv) in
            let qty = inv.quantity
            return sum + qty
        }
    }

    func getTotalQuantity(forItem item_stable_id: String, type: String) async throws -> Double {
        let items = try await fetchInventory(forItem: item_stable_id, type: type)
        return items.reduce(0.0) { (sum, inv) in
            let qty = inv.quantity
            return sum + qty
        }
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, type: String) async throws -> InventoryModel {
        let existing = try await fetchInventory(forItem: item_stable_id, type: type).first

        if let existing = existing {
            let existingQty = existing.quantity
            let existingId = existing.id
            let existingLocation = existing.location
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

        let existingQty = existing.quantity
        let newQty = existingQty - quantity

        if newQty <= 0 {
            let existingId = existing.id
            try await deleteInventory(id: existingId)
            return nil
        } else {
            let existingId = existing.id
            let existingLocation = existing.location
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
            let existingId = existing.id
            let existingLocation = existing.location
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
        let types = Set(inventoryArray.map { (inv: InventoryModel) in inv.type })
        return types.sorted()
    }

    func getItemsWithInventory() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        let items = Set(inventoryArray.map { (inv: InventoryModel) in inv.item_stable_id })
        return items.sorted()
    }

    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        let items = Set(inventoryArray.filter { (inv: InventoryModel) in
            let invType = inv.type
            return invType == type
        }.map { (inv: InventoryModel) in inv.item_stable_id })
        return items.sorted()
    }

    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_stable_id: String, type: String, quantity: Double)] {
        let inventoryArray = Array(inventory.values)
        return inventoryArray.filter { (inv: InventoryModel) in
            let qty = inv.quantity
            return qty > 0 && qty < threshold
        }.map { (inv: InventoryModel) in
            let itemId = inv.item_stable_id
            let type = inv.type
            let qty = inv.quantity
            return (item_stable_id: itemId, type: type, quantity: qty)
        }
    }

    func getItemsWithZeroInventory() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        let items = Set(inventoryArray.filter { (inv: InventoryModel) in
            let qty = inv.quantity
            return qty == 0
        }.map { (inv: InventoryModel) in inv.item_stable_id })
        return items.sorted()
    }

    // MARK: - Aggregation Operations

    func getInventorySummary() async throws -> [InventorySummaryModel] {
        var summaries: [String: InventorySummaryModel] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            let itemId = inv.item_stable_id
            let type = inv.type
            let qty = inv.quantity

            if var existing = summaries[itemId] {
                existing.types[type] = (existing.types[type] ?? 0) + qty
                summaries[itemId] = existing
            } else {
                summaries[itemId] = InventorySummaryModel(
                    item_stable_id: itemId,
                    types: [type: qty]
                )
            }
        }

        return Array(summaries.values).sorted { (a, b) in
            let aId = a.item_stable_id
            let bId = b.item_stable_id
            return aId < bId
        }
    }

    func getInventorySummary(forItem item_stable_id: String) async throws -> InventorySummaryModel? {
        let items = try await fetchInventory(forItem: item_stable_id)
        guard !items.isEmpty else { return nil }

        var types: [String: Double] = [:]
        for inv in items {
            let type = inv.type
            let qty = inv.quantity
            types[type] = (types[type] ?? 0) + qty
        }

        return InventorySummaryModel(item_stable_id: item_stable_id, types: types)
    }

    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        var values: [String: Double] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            let itemId = inv.item_stable_id
            let qty = inv.quantity
            values[itemId] = (values[itemId] ?? 0) + (qty * defaultPricePerUnit)
        }

        return values
    }

    // MARK: - Location Operations

    func fetchInventory(atLocation location: String) async throws -> [InventoryModel] {
        let inventoryArray = Array(inventory.values)
        return inventoryArray.filter { (inv: InventoryModel) in
            let invLocation = inv.location
            return invLocation == location
        }
    }

    func getDistinctLocations() async throws -> [String] {
        let inventoryArray = Array(inventory.values)
        let locations = Set(inventoryArray.compactMap { (inv: InventoryModel) in inv.location })
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
            let itemId = inv.item_stable_id
            let qty = inv.quantity
            utilization[itemId] = (utilization[itemId] ?? 0) + qty
        }

        return utilization
    }

    func getAllLocationUtilization() async throws -> [String: Double] {
        var utilization: [String: Double] = [:]

        let inventoryArray = Array(inventory.values)
        for inv in inventoryArray {
            if let location = inv.location {
                let qty = inv.quantity
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
}
