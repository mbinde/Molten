//
//  MockLocationRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

@preconcurrency import Foundation

/// Mock implementation of LocationRepository for testing
/// Provides in-memory storage for location records with realistic behavior
class MockLocationRepository: LocationRepository {

    // MARK: - Test Data Storage

    private var locations: [LocationModel] = []
    
    // MARK: - Test Configuration
    
    /// Controls whether operations should simulate network delays
    var simulateLatency: Bool = false
    
    /// Controls whether operations should randomly fail for error testing
    var shouldRandomlyFail: Bool = false
    
    /// Controls the probability of random failures (0.0 to 1.0)
    var failureProbability: Double = 0.1
    
    // MARK: - Test State Management
    
    /// Clear all stored data (useful for test setup)
    func clearAllData() {
        locations.removeAll()
    }
    
    /// Get count of stored location records (for testing)
    func getLocationCount() async -> Int {
        return locations.count
    }
    
    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testUUID1 = UUID()
        let testUUID2 = UUID()
        let testUUID3 = UUID()
        
        let testLocations = [
            LocationModel(inventory_id: testUUID1, location: "Bin 1", quantity: 7.0),
            LocationModel(inventory_id: testUUID2, location: "Shelf 1", quantity: 12.0),
            LocationModel(inventory_id: testUUID2, location: "Bin 2", quantity: 3.0),
            LocationModel(inventory_id: testUUID3, location: "Storage", quantity: 5.8)
        ]
        
        _ = try await createLocations(testLocations)
    }
    
    // MARK: - Basic CRUD Operations

    @preconcurrency func fetchLocations(matching predicate: NSPredicate?) async throws -> [LocationModel] {
        return try await simulateOperation {
            let allLocations = Array(locations)
            
            guard let predicate = predicate else {
                return allLocations.sorted { $0.location < $1.location }
            }
            
            // Simple predicate evaluation for testing
            return allLocations.filter { location in
                evaluatePredicate(predicate, for: location)
            }.sorted { $0.location < $1.location }
        }
    }
    
    func fetchLocations(forInventory inventory_id: UUID) async throws -> [LocationModel] {
        return try await simulateOperation {
            return locations
                .filter { $0.inventory_id == inventory_id }
                .sorted { $0.location < $1.location }
        }
    }
    
    func fetchLocations(withName locationName: String) async throws -> [LocationModel] {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            return locations
                .filter { $0.location == cleanLocation }
                .sorted { $0.inventory_id.uuidString < $1.inventory_id.uuidString }
        }
    }
    
    func createLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await simulateOperation {
            locations.append(location)
            return location
        }
    }

    func createLocations(_ locations: [LocationModel]) async throws -> [LocationModel] {
        return try await simulateOperation {
            self.locations.append(contentsOf: locations)
            return locations
        }
    }

    func updateLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await simulateOperation {
            // Remove old version if exists by ID, then append updated
            locations.removeAll { $0.id == location.id }
            locations.append(location)
            return location
        }
    }

    func deleteLocation(_ location: LocationModel) async throws {
        try await simulateOperation {
            locations.removeAll { $0.id == location.id }
        }
    }
    
    func deleteLocations(forInventory inventory_id: UUID) async throws {
        try await simulateOperation {
            locations = locations.filter { $0.inventory_id != inventory_id }
        }
    }
    
    func deleteLocations(withName locationName: String) async throws {
        try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            locations = locations.filter { $0.location != cleanLocation }
        }
    }
    
    // MARK: - Location Management Operations
    
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventory_id: UUID) async throws {
        try await simulateOperation {
            // Remove all existing locations for this inventory
            self.locations = self.locations.filter { $0.inventory_id != inventory_id }

            // Add new locations
            for (locationName, quantity) in locations {
                let locationModel = LocationModel(
                    inventory_id: inventory_id,
                    location: locationName,
                    quantity: quantity
                )
                self.locations.append(locationModel)
            }
        }
    }
    
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)

            // Find existing location or create new one
            let existingLocation = locations.first {
                $0.inventory_id == inventory_id && $0.location == cleanLocation
            }

            let updatedLocation: LocationModel
            if let existing = existingLocation {
                // Remove old version
                locations.removeAll { $0.id == existing.id }
                // Create updated version
                updatedLocation = LocationModel(
                    inventory_id: existing.inventory_id,
                    location: existing.location,
                    quantity: existing.quantity + quantity
                )
            } else {
                // Create new location
                updatedLocation = LocationModel(
                    inventory_id: inventory_id,
                    location: cleanLocation,
                    quantity: quantity
                )
            }

            locations.append(updatedLocation)
            return updatedLocation
        }
    }

    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel? {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)

            guard let existingLocation = locations.first(where: {
                $0.inventory_id == inventory_id && $0.location == cleanLocation
            }) else {
                throw MockLocationRepositoryError.locationNotFound(inventory_id, cleanLocation)
            }

            // Remove existing location
            locations.removeAll { $0.id == existingLocation.id }

            let newQuantity = existingLocation.quantity - quantity

            if newQuantity <= 0 {
                // Don't add back if quantity reaches zero
                return nil
            } else {
                let updatedLocation = LocationModel(
                    inventory_id: existingLocation.inventory_id,
                    location: existingLocation.location,
                    quantity: newQuantity
                )
                locations.append(updatedLocation)
                return updatedLocation
            }
        }
    }
    
    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventory_id: UUID) async throws {
        try await simulateOperation {
            _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventory_id)
            _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventory_id)
        }
    }
    
    // MARK: - Discovery Operations
    
    func getDistinctLocationNames() async throws -> [String] {
        return try await simulateOperation {
            return Array(Set(locations.map { $0.location })).sorted()
        }
    }
    
    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            let allNames = Set(locations.map { $0.location })
            return allNames.filter { $0.lowercased().hasPrefix(lowercasePrefix) }.sorted()
        }
    }
    
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            let inventoriesInLocation = Set(locations
                .filter { $0.location == cleanLocation }
                .map { $0.inventory_id })
            return Array(inventoriesInLocation).sorted { $0.uuidString < $1.uuidString }
        }
    }
    
    func getLocationUtilization() async throws -> [String: Double] {
        return try await simulateOperation {
            return Dictionary(grouping: locations, by: { $0.location })
                .mapValues { locationGroup in
                    locationGroup.reduce(0.0) { $0 + $1.quantity }
                }
        }
    }
    
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        return try await simulateOperation {
            return Dictionary(grouping: locations, by: { $0.location })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
                .map { (location: $0.key, usageCount: $0.value) }
        }
    }
    
    // MARK: - Validation Operations
    
    func validateLocationQuantities(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Bool {
        return try await simulateOperation {
            let actualTotal = locations
                .filter { $0.inventory_id == inventory_id }
                .reduce(0.0) { $0 + $1.quantity }
            
            let tolerance = 0.001 // Small tolerance for floating point comparison
            return abs(actualTotal - expectedTotal) <= tolerance
        }
    }
    
    func getLocationQuantityDiscrepancy(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Double {
        return try await simulateOperation {
            let actualTotal = locations
                .filter { $0.inventory_id == inventory_id }
                .reduce(0.0) { $0 + $1.quantity }
            
            return actualTotal - expectedTotal
        }
    }
    
    func findOrphanedLocations() async throws -> [LocationModel] {
        return try await simulateOperation {
            // In a mock implementation, we don't track inventory validity,
            // so we'll return an empty array. In a real implementation,
            // this would check against actual inventory records.
            return []
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockLocationRepositoryError.simulatedFailure
        }
        
        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.03) // 10-30ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return try await operation()
    }
    
    /// Basic predicate evaluation for testing (supports common patterns)
    private func evaluatePredicate(_ predicate: NSPredicate, for location: LocationModel) -> Bool {
        let predicateString = predicate.predicateFormat
        
        // Handle common predicate patterns
        if predicateString.contains("inventory_id ==") {
            // Extract UUID from predicate - this is simplified for testing
            if predicateString.contains(location.inventory_id.uuidString) {
                return true
            }
        }
        
        if predicateString.contains("location ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let locationName = String(afterFirstQuote[..<endRange.lowerBound])
                    return location.location == locationName
                }
            }
        }
        
        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Mock Repository Errors

enum MockLocationRepositoryError: Error, LocalizedError {
    case locationNotFound(UUID, String)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .locationNotFound(let inventory_id, let locationName):
            return "Location not found: \(locationName) for inventory: \(inventory_id)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}
