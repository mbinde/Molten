//
//  MockStorageLocationRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of StorageLocationRepository for testing
//

import Foundation

/// Mock implementation of StorageLocationRepository for testing
/// Stores storage locations in memory using a dictionary
@MainActor
final class MockStorageLocationRepository: StorageLocationRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var locations: [UUID: StorageLocationModel] = [:] // Key: id

    // MARK: - CRUD Operations

    func fetchLocations(matching predicate: NSPredicate?) async throws -> [StorageLocationModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(locations.values)
    }

    func fetchLocations(forInventory inventoryId: UUID) async throws -> [StorageLocationModel] {
        return locations.values.filter { $0.inventoryId == inventoryId }
    }

    func fetchLocations(withName locationName: String) async throws -> [StorageLocationModel] {
        return locations.values.filter { $0.locationName == locationName }
    }

    func createLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        locations[location.id] = location
        return location
    }

    func createLocations(_ locations: [StorageLocationModel]) async throws -> [StorageLocationModel] {
        for location in locations {
            self.locations[location.id] = location
        }
        return locations
    }

    func updateLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        guard self.locations[location.id] != nil else {
            throw NSError(domain: "MockLocationRepository", code: 404)
        }
        self.locations[location.id] = location
        return location
    }

    func deleteLocation(_ location: StorageLocationModel) async throws {
        locations.removeValue(forKey: location.id)
    }

    func deleteLocations(forInventory inventoryId: UUID) async throws {
        for (id, loc) in locations {
            if loc.inventoryId == inventoryId {
                locations.removeValue(forKey: id)
            }
        }
    }

    func deleteLocations(withName locationName: String) async throws {
        for (id, loc) in locations {
            if loc.locationName == locationName {
                locations.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Location Management Operations

    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventoryId: UUID) async throws {
        // Delete existing
        try await deleteLocations(forInventory: inventoryId)

        // Create new
        for (locationName, quantity) in locations {
            let loc = StorageLocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                locationName: locationName,
                quantity: quantity
            )
            _ = try await createLocation(loc)
        }
    }

    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventoryId: UUID) async throws -> StorageLocationModel {
        let locs = try await fetchLocations(forInventory: inventoryId)
        let existing = locs.first { $0.locationName == locationName }

        if let existing = existing {
            let updated = StorageLocationModel(
                id: existing.id,
                inventoryId: inventoryId,
                storageLocationId: existing.storageLocationId,
                locationName: locationName,
                quantity: existing.quantity + quantity,
                workspaceId: existing.workspaceId
            )
            return try await updateLocation(updated)
        } else {
            let new = StorageLocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                locationName: locationName,
                quantity: quantity
            )
            return try await createLocation(new)
        }
    }

    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventoryId: UUID) async throws -> StorageLocationModel? {
        let locs = try await fetchLocations(forInventory: inventoryId)
        guard let existing = locs.first(where: { $0.locationName == locationName }) else {
            throw NSError(domain: "MockLocationRepository", code: 404)
        }

        let newQty = existing.quantity - quantity

        if newQty <= 0 {
            try await deleteLocation(existing)
            return nil
        } else {
            let updated = StorageLocationModel(
                id: existing.id,
                inventoryId: inventoryId,
                storageLocationId: existing.storageLocationId,
                locationName: locationName,
                quantity: newQty,
                workspaceId: existing.workspaceId
            )
            return try await updateLocation(updated)
        }
    }

    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventoryId: UUID) async throws {
        _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventoryId)
        _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventoryId)
    }

    // MARK: - Discovery Operations

    func getDistinctLocationNames() async throws -> [String] {
        let names = Set(locations.values.map { $0.locationName })
        return names.sorted()
    }

    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let names = try await getDistinctLocationNames()
        let lowercasePrefix = prefix.lowercased()
        return names.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
    }

    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        let inventoryIds = locations.values
            .filter { $0.locationName == locationName }
            .map { $0.inventoryId }
        return Array(Set(inventoryIds)).sorted { $0.uuidString < $1.uuidString }
    }

    func getLocationUtilization() async throws -> [String: Double] {
        var utilization: [String: Double] = [:]
        for loc in locations.values {
            utilization[loc.locationName] = (utilization[loc.locationName] ?? 0) + loc.quantity
        }
        return utilization
    }

    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        var counts: [String: Int] = [:]
        for loc in locations.values {
            counts[loc.locationName] = (counts[loc.locationName] ?? 0) + 1
        }
        return counts.map { (location: $0.key, usageCount: $0.value) }
            .sorted { $0.location < $1.location }
    }

    // MARK: - Validation Operations

    func validateLocationQuantities(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Bool {
        let locs = try await fetchLocations(forInventory: inventoryId)
        let total = locs.reduce(0.0) { $0 + $1.quantity }
        return abs(total - expectedTotal) < 0.001 // Tolerance for floating point
    }

    func getLocationQuantityDiscrepancy(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Double {
        let locs = try await fetchLocations(forInventory: inventoryId)
        let total = locs.reduce(0.0) { $0 + $1.quantity }
        return total - expectedTotal
    }

    func findOrphanedLocations() async throws -> [StorageLocationModel] {
        // In a mock, we can't easily validate against actual inventory records
        // so just return empty for simplicity
        return []
    }

    // MARK: - Date and Transfer Operations

    func fetchLocations(addedOn date: Date, excludeTransfers: Bool) async throws -> [StorageLocationModel] {
        let calendar = Calendar.current
        return locations.values.filter { location in
            let sameDay = calendar.isDate(location.dateAdded, inSameDayAs: date)
            let passesTransferFilter = !excludeTransfers || !location.isTransfer
            let hasQuantity = location.quantity > 0
            return sameDay && passesTransferFilter && hasQuantity
        }
    }

    func fetchTransferLocations() async throws -> [StorageLocationModel] {
        return locations.values.filter { $0.isTransfer }
    }

    func fetchLocations(atLocationDefinition storageLocationId: UUID) async throws -> [StorageLocationModel] {
        return locations.values.filter { $0.storageLocationId == storageLocationId }
    }

    // MARK: - Test Helpers

    /// Populate repository with sample test data
    func populateWithTestData() async throws {
        let testInventoryId = UUID()
        let testLocations = [
            StorageLocationModel(id: UUID(), inventoryId: testInventoryId, locationName: "Workshop Shelf A", quantity: 10.0),
            StorageLocationModel(id: UUID(), inventoryId: testInventoryId, locationName: "Workshop Shelf B", quantity: 20.0),
            StorageLocationModel(id: UUID(), inventoryId: testInventoryId, locationName: "Bin 1", quantity: 5.0),
            StorageLocationModel(id: UUID(), inventoryId: testInventoryId, locationName: "Bin 2", quantity: 15.0),
            StorageLocationModel(id: UUID(), inventoryId: testInventoryId, locationName: "Storage Room", quantity: 30.0)
        ]
        _ = try await createLocations(testLocations)
    }

    /// Get count of stored locations (test helper)
    func getLocationCount() async -> Int {
        return locations.count
    }

    /// Clear all locations (test helper)
    func clearAll() async {
        locations.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    nonisolated func clearAllData() {
        locations.removeAll()
    }
}
