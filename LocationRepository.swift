//
//  LocationRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for Location data persistence operations
/// Handles location-based inventory storage tracking
protocol LocationRepository {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all location records matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of LocationModel instances
    func fetchLocations(matching predicate: NSPredicate?) async throws -> [LocationModel]
    
    /// Fetch all locations for a specific inventory record
    /// - Parameter inventoryId: The UUID of the inventory record
    /// - Returns: Array of LocationModel instances for the inventory
    func fetchLocations(forInventory inventoryId: UUID) async throws -> [LocationModel]
    
    /// Fetch all locations with a specific location name
    /// - Parameter locationName: The location name to search for
    /// - Returns: Array of LocationModel instances with this location name
    func fetchLocations(withName locationName: String) async throws -> [LocationModel]
    
    /// Create a new location record
    /// - Parameter location: The LocationModel to create
    /// - Returns: The created LocationModel
    func createLocation(_ location: LocationModel) async throws -> LocationModel
    
    /// Create multiple location records in a batch operation
    /// - Parameter locations: Array of LocationModel instances to create
    /// - Returns: Array of created LocationModel instances
    func createLocations(_ locations: [LocationModel]) async throws -> [LocationModel]
    
    /// Update an existing location record
    /// - Parameter location: The LocationModel with updated values
    /// - Returns: The updated LocationModel
    func updateLocation(_ location: LocationModel) async throws -> LocationModel
    
    /// Delete a location record
    /// - Parameter location: The LocationModel to delete
    func deleteLocation(_ location: LocationModel) async throws
    
    /// Delete all locations for a specific inventory record
    /// - Parameter inventoryId: The UUID of the inventory record
    func deleteLocations(forInventory inventoryId: UUID) async throws
    
    /// Delete all locations with a specific location name
    /// - Parameter locationName: The location name
    func deleteLocations(withName locationName: String) async throws
    
    // MARK: - Location Management Operations
    
    /// Set the exact locations for an inventory record (replaces all existing)
    /// - Parameters:
    ///   - locations: Array of location names with quantities
    ///   - inventoryId: The UUID of the inventory record
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventoryId: UUID) async throws
    
    /// Add quantity to a specific location for an inventory record
    /// - Parameters:
    ///   - quantity: Amount to add
    ///   - locationName: The location name
    ///   - inventoryId: The UUID of the inventory record
    /// - Returns: The updated or created LocationModel
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventoryId: UUID) async throws -> LocationModel
    
    /// Subtract quantity from a specific location for an inventory record
    /// - Parameters:
    ///   - quantity: Amount to subtract
    ///   - locationName: The location name
    ///   - inventoryId: The UUID of the inventory record
    /// - Returns: The updated LocationModel, or nil if record was deleted due to zero quantity
    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventoryId: UUID) async throws -> LocationModel?
    
    /// Move quantity from one location to another within the same inventory record
    /// - Parameters:
    ///   - quantity: Amount to move
    ///   - fromLocation: Source location name
    ///   - toLocation: Destination location name
    ///   - inventoryId: The UUID of the inventory record
    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventoryId: UUID) async throws
    
    // MARK: - Discovery Operations
    
    /// Get all distinct location names in the system (for autocomplete)
    /// - Returns: Sorted array of location name strings
    func getDistinctLocationNames() async throws -> [String]
    
    /// Get location names that start with a specific prefix (for autocomplete)
    /// - Parameter prefix: The prefix to search for
    /// - Returns: Sorted array of matching location name strings
    func getLocationNames(withPrefix prefix: String) async throws -> [String]
    
    /// Get all inventory records that have items stored in a specific location
    /// - Parameter locationName: The location name to search for
    /// - Returns: Array of inventory UUIDs that use this location
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID]
    
    /// Get location utilization summary
    /// - Returns: Dictionary mapping location names to total quantities stored
    func getLocationUtilization() async throws -> [String: Double]
    
    /// Get locations with their usage counts (how many inventory records use each location)
    /// - Returns: Array of tuples containing location name and usage count
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)]
    
    // MARK: - Validation Operations
    
    /// Validate that location quantities sum correctly for an inventory record
    /// - Parameters:
    ///   - inventoryId: The UUID of the inventory record
    ///   - expectedTotal: The expected total quantity
    /// - Returns: True if quantities sum to expected total within tolerance
    func validateLocationQuantities(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Bool
    
    /// Get location quantity discrepancies for an inventory record
    /// - Parameters:
    ///   - inventoryId: The UUID of the inventory record
    ///   - expectedTotal: The expected total quantity
    /// - Returns: The difference between actual and expected (positive = more than expected)
    func getLocationQuantityDiscrepancy(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Double
    
    /// Find locations with quantities but no corresponding inventory records
    /// - Returns: Array of LocationModel instances that are orphaned
    func findOrphanedLocations() async throws -> [LocationModel]
}

/// Domain model representing a location storage record
struct LocationModel {
    let inventoryId: UUID
    let location: String
    let quantity: Double
    
    init(inventoryId: UUID, location: String, quantity: Double) {
        self.inventoryId = inventoryId
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
    }
}

// MARK: - LocationModel Extensions

extension LocationModel: Equatable {
    static func == (lhs: LocationModel, rhs: LocationModel) -> Bool {
        return lhs.inventoryId == rhs.inventoryId && lhs.location == rhs.location
    }
}

extension LocationModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(inventoryId)
        hasher.combine(location)
    }
}

extension LocationModel: Identifiable {
    var id: String { "\(inventoryId.uuidString)-\(location)" }
}

// MARK: - Location Helper

extension LocationModel {
    /// Common location types/patterns
    enum CommonLocation {
        static let bin1 = "Bin 1"
        static let bin2 = "Bin 2"
        static let shelf1 = "Shelf 1"
        static let shelf2 = "Shelf 2"
        static let storage = "Storage"
        static let workbench = "Workbench"
        static let kiln = "Kiln Area"
        
        static let allCommonLocations = [bin1, bin2, shelf1, shelf2, storage, workbench, kiln]
    }
    
    /// Validates that a location name is valid
    /// - Parameter location: The location name to validate
    /// - Returns: True if valid, false otherwise
    static func isValidLocation(_ location: String) -> Bool {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
    
    /// Cleans and normalizes a location name
    /// - Parameter location: The raw location name
    /// - Returns: Cleaned location name suitable for storage
    static func cleanLocation(_ location: String) -> String {
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Parses location suggestions from a partial input (for autocomplete)
    /// - Parameters:
    ///   - input: Partial location name input
    ///   - existingLocations: Array of existing location names for suggestions
    /// - Returns: Array of suggested location names
    static func suggestLocations(for input: String, from existingLocations: [String]) -> [String] {
        let cleanInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return Array(CommonLocation.allCommonLocations) }
        
        let matchingExisting = existingLocations.filter { location in
            location.lowercased().contains(cleanInput)
        }
        
        let matchingCommon = CommonLocation.allCommonLocations.filter { location in
            location.lowercased().contains(cleanInput)
        }
        
        return Array(Set(matchingExisting + matchingCommon)).sorted()
    }
}