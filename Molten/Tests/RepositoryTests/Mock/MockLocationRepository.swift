//
//  MockLocationRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of LocationRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of LocationRepository for testing
/// Stores locations in memory using a dictionary
@MainActor
final class MockLocationRepository: LocationRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var locations: [UUID: StorageLocationModel] = [:] // Key: id

    // MARK: - CRUD Operations

    func fetchLocations(matching predicate: NSPredicate?) async throws -> [StorageLocationModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(locations.values)
    }

    func fetchLocations(forInventory inventory_id: UUID) async throws -> [StorageLocationModel] {
        let locationsArray = Array(locations.values)
        return locationsArray.filter { (loc: StorageLocationModel) in
            let locInventoryId = loc.inventory_id
            return locInventoryId == inventory_id
        }
    }

    func fetchLocations(withName locationName: String) async throws -> [StorageLocationModel] {
        let locationsArray = Array(locations.values)
        return locationsArray.filter { (loc: StorageLocationModel) in
            let locName = loc.location
            return locName == locationName
        }
    }

    func createLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        let id = location.id
        locations[id] = location
        return location
    }

    func createLocations(_ locations: [StorageLocationModel]) async throws -> [StorageLocationModel] {
        for location in locations {
            let id = location.id
            self.locations[id] = location
        }
        return locations
    }

    func updateLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        let id = location.id
        guard locations[id] != nil else {
            throw NSError(domain: "MockLocationRepository", code: 404)
        }
        locations[id] = location
        return location
    }

    func deleteLocation(_ location: StorageLocationModel) async throws {
        let id = location.id
        locations.removeValue(forKey: id)
    }

    func deleteLocations(forInventory inventory_id: UUID) async throws {
        let locationsArray = Array(locations)
        for (id, loc) in locationsArray {
            let locInventoryId = loc.inventory_id
            if locInventoryId == inventory_id {
                locations.removeValue(forKey: id)
            }
        }
    }

    func deleteLocations(withName locationName: String) async throws {
        let locationsArray = Array(locations)
        for (id, loc) in locationsArray {
            let locName = loc.location
            if locName == locationName {
                locations.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Location Management Operations

    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventory_id: UUID) async throws {
        // Delete existing
        try await deleteLocations(forInventory: inventory_id)

        // Create new
        for (locationName, quantity) in locations {
            let loc = StorageLocationModel(
                id: UUID(),
                inventory_id: inventory_id,
                location: locationName,
                quantity: quantity
            )
            _ = try await createLocation(loc)
        }
    }

    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventory_id: UUID) async throws -> StorageLocationModel {
        let locs = try await fetchLocations(forInventory: inventory_id)
        let existing = locs.first { (loc: StorageLocationModel) in
            let locName = loc.location
            return locName == locationName
        }

        if let existing = existing {
            let existingQty = existing.quantity
            let existingId = existing.id
            let updated = StorageLocationModel(
                id: existingId,
                inventory_id: inventory_id,
                location: locationName,
                quantity: existingQty + quantity
            )
            return try await updateLocation(updated)
        } else {
            let new = StorageLocationModel(
                id: UUID(),
                inventory_id: inventory_id,
                location: locationName,
                quantity: quantity
            )
            return try await createLocation(new)
        }
    }

    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventory_id: UUID) async throws -> StorageLocationModel? {
        let locs = try await fetchLocations(forInventory: inventory_id)
        guard let existing = locs.first(where: { (loc: StorageLocationModel) in
            let locName = loc.location
            return locName == locationName
        }) else {
            throw NSError(domain: "MockLocationRepository", code: 404)
        }

        let existingQty = existing.quantity
        let newQty = existingQty - quantity

        if newQty <= 0 {
            try await deleteLocation(existing)
            return nil
        } else {
            let existingId = existing.id
            let updated = StorageLocationModel(
                id: existingId,
                inventory_id: inventory_id,
                location: locationName,
                quantity: newQty
            )
            return try await updateLocation(updated)
        }
    }

    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventory_id: UUID) async throws {
        _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventory_id)
        _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventory_id)
    }

    // MARK: - Discovery Operations

    func getDistinctLocationNames() async throws -> [String] {
        let locationsArray = Array(locations.values)
        var namesSet: Set<String> = []
        for loc in locationsArray {
            let location = loc.location
            namesSet.insert(location)
        }
        return namesSet.sorted()
    }

    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let names = try await getDistinctLocationNames()
        return names.filter { $0.hasPrefix(prefix) }
    }

    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        let locationsArray = Array(locations.values)
        var inventoriesSet: Set<UUID> = []
        for loc in locationsArray {
            let locName = loc.location
            if locName == locationName {
                let inventoryId = loc.inventory_id
                inventoriesSet.insert(inventoryId)
            }
        }
        return Array(inventoriesSet).sorted()
    }

    func getLocationUtilization() async throws -> [String: Double] {
        var utilization: [String: Double] = [:]

        let locationsArray = Array(locations.values)
        for loc in locationsArray {
            let name = loc.location
            let qty = loc.quantity
            utilization[name] = (utilization[name] ?? 0) + qty
        }

        return utilization
    }

    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        var counts: [String: Int] = [:]

        let locationsArray = Array(locations.values)
        for loc in locationsArray {
            let name = loc.location
            counts[name] = (counts[name] ?? 0) + 1
        }

        return counts.map { (location: $0.key, usageCount: $0.value) }
            .sorted { $0.location < $1.location }
    }

    // MARK: - Validation Operations

    func validateLocationQuantities(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Bool {
        let locs = try await fetchLocations(forInventory: inventory_id)
        var total: Double = 0.0
        for loc in locs {
            let qty = loc.quantity
            total += qty
        }
        return abs(total - expectedTotal) < 0.001 // Tolerance for floating point
    }

    func getLocationQuantityDiscrepancy(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Double {
        let locs = try await fetchLocations(forInventory: inventory_id)
        var total: Double = 0.0
        for loc in locs {
            let qty = loc.quantity
            total += qty
        }
        return total - expectedTotal
    }

    func findOrphanedLocations() async throws -> [StorageLocationModel] {
        // In a mock, we can't easily validate against actual inventory records
        // so just return empty for simplicity
        return []
    }

    // MARK: - Test Helpers

    /// Get count of stored locations (test helper)
    func getLocationCount() async -> Int {
        return locations.count
    }

    /// Clear all locations (test helper)
    func clearAll() async {
        locations.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        locations.removeAll()
    }
}
