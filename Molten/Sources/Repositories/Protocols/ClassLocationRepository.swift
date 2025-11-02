//
//  ClassLocationRepository.swift
//  Molten
//
//  Created for ClassLocation Feature on 11/1/25.
//

@preconcurrency import Foundation
import CoreLocation

/// Repository protocol for ClassLocation data persistence operations
/// Handles glass art class location information and location data
nonisolated protocol ClassLocationRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all class locations
    /// - Returns: Array of ClassLocationModel instances
    func fetchAllClassLocations() async throws -> [ClassLocationModel]

    /// Fetch a class location by its stable_id
    /// - Parameter stable_id: The class location's stable identifier
    /// - Returns: ClassLocationModel if found, nil otherwise
    func fetchClassLocation(byId stable_id: String) async throws -> ClassLocationModel?

    /// Fetch class locations matching a predicate
    /// - Parameter predicate: NSPredicate for filtering
    /// - Returns: Array of matching ClassLocationModel instances
    @preconcurrency func fetchClassLocations(matching predicate: NSPredicate?) async throws -> [ClassLocationModel]

    /// Create a new class location
    /// - Parameter classLocation: The ClassLocationModel to create
    /// - Returns: The created ClassLocationModel
    func createClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel

    /// Create multiple class locations in a batch operation
    /// - Parameter classLocations: Array of ClassLocationModel instances to create
    /// - Returns: Array of created ClassLocationModel instances
    func createClassLocations(_ classLocations: [ClassLocationModel]) async throws -> [ClassLocationModel]

    /// Update an existing class location
    /// - Parameter classLocation: The ClassLocationModel with updated values
    /// - Returns: The updated ClassLocationModel
    func updateClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel

    /// Delete a class location
    /// - Parameter classLocation: The ClassLocationModel to delete
    func deleteClassLocation(_ classLocation: ClassLocationModel) async throws

    /// Delete a class location by its stable_id
    /// - Parameter stable_id: The class location's stable identifier
    func deleteClassLocation(byId stable_id: String) async throws

    /// Delete all class locations (use with caution)
    func deleteAllClassLocations() async throws

    // MARK: - Query Operations

    /// Search class locations by name, address, or notes
    /// - Parameter searchText: The text to search for
    /// - Returns: Array of matching ClassLocationModel instances
    func searchClassLocations(matching searchText: String) async throws -> [ClassLocationModel]

    /// Fetch class locations in a specific city
    /// - Parameter city: City name
    /// - Returns: Array of ClassLocationModel instances in that city
    func fetchClassLocations(inCity city: String) async throws -> [ClassLocationModel]

    /// Fetch class locations in a specific state
    /// - Parameter state: State code or name
    /// - Returns: Array of ClassLocationModel instances in that state
    func fetchClassLocations(inState state: String) async throws -> [ClassLocationModel]

    /// Fetch class locations within a radius of a coordinate
    /// - Parameters:
    ///   - coordinate: Center point coordinate
    ///   - radiusMeters: Search radius in meters
    /// - Returns: Array of ClassLocationModel instances within radius, sorted by distance
    func fetchClassLocations(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [ClassLocationModel]

    /// Fetch verified class locations only
    /// - Returns: Array of verified ClassLocationModel instances
    func fetchVerifiedClassLocations() async throws -> [ClassLocationModel]

    /// Fetch class locations with valid location data
    /// - Returns: Array of ClassLocationModel instances with non-zero coordinates
    func fetchClassLocationsWithLocation() async throws -> [ClassLocationModel]

    /// Fetch class locations that support a specific technique
    /// - Parameter technique: The technique type to filter by
    /// - Returns: Array of ClassLocationModel instances that support the technique
    func fetchClassLocations(supportingTechnique technique: TechniqueType) async throws -> [ClassLocationModel]

    /// Fetch class locations that support any of the specified techniques
    /// - Parameter techniques: Array of technique types to filter by
    /// - Returns: Array of ClassLocationModel instances that support at least one technique
    func fetchClassLocations(supportingAnyOf techniques: [TechniqueType]) async throws -> [ClassLocationModel]

    /// Fetch class locations that support all of the specified techniques
    /// - Parameter techniques: Array of technique types to filter by
    /// - Returns: Array of ClassLocationModel instances that support all techniques
    func fetchClassLocations(supportingAllOf techniques: [TechniqueType]) async throws -> [ClassLocationModel]

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

    /// Get class location count by state
    /// - Returns: Dictionary mapping state names to class location counts
    func getClassLocationCountByState() async throws -> [String: Int]

    /// Get class location count by city
    /// - Returns: Dictionary mapping city names to class location counts
    func getClassLocationCountByCity() async throws -> [String: Int]

    // MARK: - Bulk Operations

    /// Load class locations from JSON data
    /// - Parameter data: JSON data containing class location information
    /// - Returns: Number of class locations loaded
    func loadClassLocationsFromJSON(_ data: Data) async throws -> Int

    /// Load class locations from a JSON file
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: Number of class locations loaded
    func loadClassLocationsFromJSONFile(at fileURL: URL) async throws -> Int

    /// Export all class locations to JSON data
    /// - Returns: JSON data containing all class locations
    func exportClassLocationsToJSON() async throws -> Data

    /// Check if a class location with the given stable_id exists
    /// - Parameter stable_id: The class location's stable identifier
    /// - Returns: True if class location exists
    func classLocationExists(withId stable_id: String) async throws -> Bool

    // MARK: - Statistics Operations

    /// Get total number of class locations
    /// - Returns: Count of all class locations
    func getClassLocationCount() async throws -> Int

    /// Get number of verified class locations
    /// - Returns: Count of verified class locations
    func getVerifiedClassLocationCount() async throws -> Int

    /// Get number of class locations with valid location data
    /// - Returns: Count of class locations with non-zero coordinates
    func getClassLocationsWithLocationCount() async throws -> Int
}
