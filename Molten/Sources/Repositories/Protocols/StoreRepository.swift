//
//  StoreRepository.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

@preconcurrency import Foundation
import CoreLocation

/// Repository protocol for Store data persistence operations
/// Handles local glass store information and location data
nonisolated protocol StoreRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all stores
    /// - Returns: Array of StoreModel instances
    func fetchAllStores() async throws -> [StoreModel]

    /// Fetch a store by its stable_id
    /// - Parameter stable_id: The store's stable identifier
    /// - Returns: StoreModel if found, nil otherwise
    func fetchStore(byId stable_id: String) async throws -> StoreModel?

    /// Fetch stores matching a predicate
    /// - Parameter predicate: NSPredicate for filtering
    /// - Returns: Array of matching StoreModel instances
    @preconcurrency func fetchStores(matching predicate: NSPredicate?) async throws -> [StoreModel]

    /// Create a new store
    /// - Parameter store: The StoreModel to create
    /// - Returns: The created StoreModel
    func createStore(_ store: StoreModel) async throws -> StoreModel

    /// Create multiple stores in a batch operation
    /// - Parameter stores: Array of StoreModel instances to create
    /// - Returns: Array of created StoreModel instances
    func createStores(_ stores: [StoreModel]) async throws -> [StoreModel]

    /// Update an existing store
    /// - Parameter store: The StoreModel with updated values
    /// - Returns: The updated StoreModel
    func updateStore(_ store: StoreModel) async throws -> StoreModel

    /// Delete a store
    /// - Parameter store: The StoreModel to delete
    func deleteStore(_ store: StoreModel) async throws

    /// Delete a store by its stable_id
    /// - Parameter stable_id: The store's stable identifier
    func deleteStore(byId stable_id: String) async throws

    /// Delete all stores (use with caution)
    func deleteAllStores() async throws

    // MARK: - Query Operations

    /// Search stores by name, address, or notes
    /// - Parameter searchText: The text to search for
    /// - Returns: Array of matching StoreModel instances
    func searchStores(matching searchText: String) async throws -> [StoreModel]

    /// Fetch stores in a specific city
    /// - Parameter city: City name
    /// - Returns: Array of StoreModel instances in that city
    func fetchStores(inCity city: String) async throws -> [StoreModel]

    /// Fetch stores in a specific state
    /// - Parameter state: State code or name
    /// - Returns: Array of StoreModel instances in that state
    func fetchStores(inState state: String) async throws -> [StoreModel]

    /// Fetch stores within a radius of a coordinate
    /// - Parameters:
    ///   - coordinate: Center point coordinate
    ///   - radiusMeters: Search radius in meters
    /// - Returns: Array of StoreModel instances within radius, sorted by distance
    func fetchStores(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [StoreModel]

    /// Fetch verified stores only
    /// - Returns: Array of verified StoreModel instances
    func fetchVerifiedStores() async throws -> [StoreModel]

    /// Fetch stores with valid location data
    /// - Returns: Array of StoreModel instances with non-zero coordinates
    func fetchStoresWithLocation() async throws -> [StoreModel]

    /// Fetch stores that support a specific technique
    /// - Parameter technique: The technique type to filter by
    /// - Returns: Array of StoreModel instances that support the technique
    func fetchStores(supportingTechnique technique: TechniqueType) async throws -> [StoreModel]

    /// Fetch stores that support any of the specified techniques
    /// - Parameter techniques: Array of technique types to filter by
    /// - Returns: Array of StoreModel instances that support at least one technique
    func fetchStores(supportingAnyOf techniques: [TechniqueType]) async throws -> [StoreModel]

    /// Fetch stores that support all of the specified techniques
    /// - Parameter techniques: Array of technique types to filter by
    /// - Returns: Array of StoreModel instances that support all techniques
    func fetchStores(supportingAllOf techniques: [TechniqueType]) async throws -> [StoreModel]

    // MARK: - Discovery Operations

    /// Get all distinct city names (for autocomplete)
    /// - Returns: Sorted array of city name strings
    func getDistinctCities() async throws -> [String]

    /// Get all distinct state names (for autocomplete)
    /// - Returns: Sorted array of state name strings
    func getDistinctStates() async throws -> [String]

    /// Get city names that start with a specific prefix (for autocomplete)
    /// - Parameter prefix: The prefix to search for
    /// - Returns: Sorted array of matching city name strings
    func getCities(withPrefix prefix: String) async throws -> [String]

    /// Get state names that start with a specific prefix (for autocomplete)
    /// - Parameter prefix: The prefix to search for
    /// - Returns: Sorted array of matching state name strings
    func getStates(withPrefix prefix: String) async throws -> [String]

    /// Get store count by state
    /// - Returns: Dictionary mapping state names to store counts
    func getStoreCountByState() async throws -> [String: Int]

    /// Get store count by city
    /// - Returns: Dictionary mapping city names to store counts
    func getStoreCountByCity() async throws -> [String: Int]

    // MARK: - Bulk Operations

    /// Load stores from JSON data
    /// - Parameter data: JSON data containing store information
    /// - Returns: Number of stores loaded
    func loadStoresFromJSON(_ data: Data) async throws -> Int

    /// Load stores from a JSON file
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: Number of stores loaded
    func loadStoresFromJSONFile(at fileURL: URL) async throws -> Int

    /// Export all stores to JSON data
    /// - Returns: JSON data containing all stores
    func exportStoresToJSON() async throws -> Data

    /// Check if a store with the given stable_id exists
    /// - Parameter stable_id: The store's stable identifier
    /// - Returns: True if store exists
    func storeExists(withId stable_id: String) async throws -> Bool

    // MARK: - Statistics Operations

    /// Get total number of stores
    /// - Returns: Count of all stores
    func getStoreCount() async throws -> Int

    /// Get number of verified stores
    /// - Returns: Count of verified stores
    func getVerifiedStoreCount() async throws -> Int

    /// Get number of stores with valid location data
    /// - Returns: Count of stores with non-zero coordinates
    func getStoresWithLocationCount() async throws -> Int
}
