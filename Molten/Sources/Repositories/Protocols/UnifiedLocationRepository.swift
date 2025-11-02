//
//  UnifiedLocationRepository.swift
//  Molten
//
//  Repository protocol for unified geographic locations (stores, studios, etc.)
//

import Foundation

/// Repository for managing geographic locations with their capabilities
protocol UnifiedLocationRepository: Sendable {
    /// Fetch all locations
    func fetchAll() async throws -> [UnifiedLocationModel]

    /// Fetch a single location by stable_id
    func fetch(stableId: String) async throws -> UnifiedLocationModel?

    /// Save a location (insert or update)
    func save(_ location: UnifiedLocationModel) async throws

    /// Save multiple locations
    func saveAll(_ locations: [UnifiedLocationModel]) async throws

    /// Delete a location by stable_id
    func delete(stableId: String) async throws

    /// Delete all locations
    func deleteAll() async throws

    /// Search locations by name, address, or capabilities
    func search(text: String) async throws -> [UnifiedLocationModel]

    /// Filter locations by retail technique
    func fetchLocationsSellingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel]

    /// Filter locations by education technique
    func fetchLocationsTeachingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel]

    /// Filter locations by service type
    func fetchLocationsOfferingService(_ service: ServiceType) async throws -> [UnifiedLocationModel]

    /// Filter locations within a radius (in meters) of coordinates
    func fetchLocationsNear(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [UnifiedLocationModel]

    /// Count total locations
    func count() async throws -> Int

    // MARK: - Bulk Data Loading

    /// Load locations from JSON data (e.g., from stores.json)
    /// - Parameter data: JSON data containing location information
    /// - Returns: Number of locations loaded
    func loadLocationsFromJSON(_ data: Data) async throws -> Int

    /// Load locations from a JSON file
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: Number of locations loaded
    func loadLocationsFromJSONFile(at fileURL: URL) async throws -> Int
}
