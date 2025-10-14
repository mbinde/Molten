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

/// Domain model representing a location entry
struct LocationModel: Identifiable, Equatable {
    let id: UUID
    let inventoryId: UUID
    let location: String
    let quantity: Double
    
    init(id: UUID = UUID(), inventoryId: UUID, location: String, quantity: Double) {
        self.id = id
        self.inventoryId = inventoryId
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
    }
}

// MARK: - LocationModel Extensions

extension LocationModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Location Validation Helper

extension LocationModel {
    /// Validates that a location name string is valid
    /// - Parameter location: The location name string to validate
    /// - Returns: True if valid, false otherwise
    static func isValidLocationName(_ location: String) -> Bool {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    /// Cleans and normalizes a location name string
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    static func cleanLocationName(_ location: String) -> String {
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Shorthand alias for cleanLocationName (for backward compatibility)
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    static func cleanLocation(_ location: String) -> String {
        return cleanLocationName(location)
    }
}