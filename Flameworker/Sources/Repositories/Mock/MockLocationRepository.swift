//
//  MockLocationRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of LocationRepository for testing
/// Provides in-memory storage for location records with realistic behavior
class MockLocationRepository: LocationRepository {
    
    // MARK: - Test Data Storage
    
    private var locations: Set<LocationModel> = []
    private let queue = DispatchQueue(label: "mock.location.repository", attributes: .concurrent)
    
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
        queue.async(flags: .barrier) {
            self.locations.removeAll()
        }
    }
    
    /// Get count of stored location records (for testing)
    func getLocationCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.locations.count)
            }
        }
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
    
    func fetchLocations(matching predicate: NSPredicate?) async throws -> [LocationModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allLocations = Array(self.locations)
                    
                    guard let predicate = predicate else {
                        continuation.resume(returning: allLocations.sorted { $0.location < $1.location })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredLocations = allLocations.filter { location in
                        self.evaluatePredicate(predicate, for: location)
                    }.sorted { $0.location < $1.location }
                    
                    continuation.resume(returning: filteredLocations)
                }
            }
        }
    }
    
    func fetchLocations(forInventory inventory_id: UUID) async throws -> [LocationModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let inventoryLocations = self.locations
                        .filter { $0.inventory_id == inventory_id }
                        .sorted { $0.location < $1.location }
                    continuation.resume(returning: Array(inventoryLocations))
                }
            }
        }
    }
    
    func fetchLocations(withName locationName: String) async throws -> [LocationModel] {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let namedLocations = self.locations
                        .filter { $0.location == cleanLocation }
                        .sorted { $0.inventory_id.uuidString < $1.inventory_id.uuidString }
                    continuation.resume(returning: Array(namedLocations))
                }
            }
        }
    }
    
    func createLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.locations.insert(location)
                    continuation.resume(returning: location)
                }
            }
        }
    }
    
    func createLocations(_ locations: [LocationModel]) async throws -> [LocationModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for location in locations {
                        self.locations.insert(location)
                    }
                    continuation.resume(returning: locations)
                }
            }
        }
    }
    
    func updateLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Remove old version if exists, then insert updated
                    self.locations.remove(location)
                    self.locations.insert(location)
                    continuation.resume(returning: location)
                }
            }
        }
    }
    
    func deleteLocation(_ location: LocationModel) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.locations.remove(location)
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteLocations(forInventory inventory_id: UUID) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.locations = self.locations.filter { $0.inventory_id != inventory_id }
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteLocations(withName locationName: String) async throws {
        try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.locations = self.locations.filter { $0.location != cleanLocation }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Location Management Operations
    
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventory_id: UUID) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Remove all existing locations for this inventory
                    self.locations = self.locations.filter { $0.inventory_id != inventory_id }
                    
                    // Add new locations
                    for (locationName, quantity) in locations {
                        let locationModel = LocationModel(
                            inventory_id: inventory_id,
                            location: locationName,
                            quantity: quantity
                        )
                        self.locations.insert(locationModel)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            
            return await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Find existing location or create new one
                    let existingLocation = self.locations.first {
                        $0.inventory_id == inventory_id && $0.location == cleanLocation
                    }
                    
                    let updatedLocation: LocationModel
                    if let existing = existingLocation {
                        // Remove old version
                        self.locations.remove(existing)
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
                    
                    self.locations.insert(updatedLocation)
                    continuation.resume(returning: updatedLocation)
                }
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel? {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    guard let existingLocation = self.locations.first(where: {
                        $0.inventory_id == inventory_id && $0.location == cleanLocation
                    }) else {
                        continuation.resume(throwing: MockLocationRepositoryError.locationNotFound(inventory_id, cleanLocation))
                        return
                    }
                    
                    // Remove existing location
                    self.locations.remove(existingLocation)
                    
                    let newQuantity = existingLocation.quantity - quantity
                    
                    if newQuantity <= 0 {
                        // Don't add back if quantity reaches zero
                        continuation.resume(returning: nil)
                    } else {
                        let updatedLocation = LocationModel(
                            inventory_id: existingLocation.inventory_id,
                            location: existingLocation.location,
                            quantity: newQuantity
                        )
                        self.locations.insert(updatedLocation)
                        continuation.resume(returning: updatedLocation)
                    }
                }
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
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let distinctNames = Set(self.locations.map { $0.location })
                    continuation.resume(returning: Array(distinctNames).sorted())
                }
            }
        }
    }
    
    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allNames = Set(self.locations.map { $0.location })
                    let matchingNames = allNames.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
                    continuation.resume(returning: Array(matchingNames).sorted())
                }
            }
        }
    }
    
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        return try await simulateOperation {
            let cleanLocation = LocationModel.cleanLocation(locationName)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let inventoriesInLocation = Set(self.locations
                        .filter { $0.location == cleanLocation }
                        .map { $0.inventory_id })
                    continuation.resume(returning: Array(inventoriesInLocation).sorted { $0.uuidString < $1.uuidString })
                }
            }
        }
    }
    
    func getLocationUtilization() async throws -> [String: Double] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let utilization = Dictionary(grouping: self.locations, by: { $0.location })
                        .mapValues { locationGroup in
                            locationGroup.reduce(0.0) { $0 + $1.quantity }
                        }
                    continuation.resume(returning: utilization)
                }
            }
        }
    }
    
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let usageCounts = Dictionary(grouping: self.locations, by: { $0.location })
                        .mapValues { $0.count }
                        .sorted { $0.value > $1.value }
                        .map { (location: $0.key, usageCount: $0.value) }
                    continuation.resume(returning: usageCounts)
                }
            }
        }
    }
    
    // MARK: - Validation Operations
    
    func validateLocationQuantities(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Bool {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let actualTotal = self.locations
                        .filter { $0.inventory_id == inventory_id }
                        .reduce(0.0) { $0 + $1.quantity }
                    
                    let tolerance = 0.001 // Small tolerance for floating point comparison
                    let isValid = abs(actualTotal - expectedTotal) <= tolerance
                    continuation.resume(returning: isValid)
                }
            }
        }
    }
    
    func getLocationQuantityDiscrepancy(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Double {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let actualTotal = self.locations
                        .filter { $0.inventory_id == inventory_id }
                        .reduce(0.0) { $0 + $1.quantity }
                    
                    let discrepancy = actualTotal - expectedTotal
                    continuation.resume(returning: discrepancy)
                }
            }
        }
    }
    
    func findOrphanedLocations() async throws -> [LocationModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    // In a mock implementation, we don't track inventory validity,
                    // so we'll return an empty array. In a real implementation,
                    // this would check against actual inventory records.
                    continuation.resume(returning: [])
                }
            }
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
