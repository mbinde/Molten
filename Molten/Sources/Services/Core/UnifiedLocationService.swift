//
//  UnifiedLocationService.swift
//  Molten
//
//  Created for Unified Locations Feature on 11/1/25.
//

import Foundation
import CoreLocation

/// Service layer that handles unified location business logic using repository pattern
/// Supports locations with retail, education, and service capabilities
class UnifiedLocationService: @unchecked Sendable {
    private let repository: UnifiedLocationRepository

    nonisolated init(repository: UnifiedLocationRepository) {
        self.repository = repository
    }

    // MARK: - Basic CRUD Operations

    /// Get all locations
    func getAllLocations() async throws -> [UnifiedLocationModel] {
        return try await repository.fetchAll()
    }

    /// Get a single location by stable_id
    func getLocation(byId stable_id: String) async throws -> UnifiedLocationModel? {
        return try await repository.fetch(stableId: stable_id)
    }

    /// Save a location (create or update)
    func saveLocation(_ location: UnifiedLocationModel) async throws {
        try await repository.save(location)
    }

    /// Save multiple locations
    func saveLocations(_ locations: [UnifiedLocationModel]) async throws {
        try await repository.saveAll(locations)
    }

    /// Delete a location by stable_id
    func deleteLocation(byId stable_id: String) async throws {
        try await repository.delete(stableId: stable_id)
    }

    /// Delete all locations
    func deleteAllLocations() async throws {
        try await repository.deleteAll()
    }

    // MARK: - Search & Filter Operations

    /// Search locations by text (name, city, state, notes, techniques, services)
    func searchLocations(searchText: String) async throws -> [UnifiedLocationModel] {
        return try await repository.search(text: searchText)
    }

    /// Get locations that sell glass for a specific technique
    func getLocations(sellingTechnique technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return try await repository.fetchLocationsSellingTechnique(technique)
    }

    /// Get locations that teach a specific technique
    func getLocations(teachingTechnique technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return try await repository.fetchLocationsTeachingTechnique(technique)
    }

    /// Get locations that support a technique (either selling OR teaching)
    func getLocations(supportingTechnique technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        let allLocations = try await getAllLocations()
        return allLocations.filter { $0.supportsTechnique(technique) }
    }

    /// Get locations that offer a specific service
    func getLocations(offeringService service: ServiceType) async throws -> [UnifiedLocationModel] {
        return try await repository.fetchLocationsOfferingService(service)
    }

    /// Get locations near a coordinate
    func getLocations(near coordinate: CLLocationCoordinate2D, radiusMeters: Double = 50000) async throws -> [UnifiedLocationModel] {
        return try await repository.fetchLocationsNear(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radiusMeters
        )
    }

    /// Get locations near a coordinate (convenience method with miles)
    func getLocations(near coordinate: CLLocationCoordinate2D, radiusMiles: Double) async throws -> [UnifiedLocationModel] {
        let radiusMeters = radiusMiles * 1609.34 // Convert miles to meters
        return try await repository.fetchLocationsNear(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radiusMeters
        )
    }

    /// Get verified locations only
    func getVerifiedLocations() async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.isVerified }
    }

    /// Get locations with valid coordinates
    func getLocationsWithValidCoordinates() async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.hasValidLocation }
    }

    /// Get locations with retail capabilities (sell glass)
    func getRetailLocations() async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.hasRetail }
    }

    /// Get locations with education capabilities (teach classes)
    func getEducationLocations() async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.hasEducation }
    }

    /// Get locations with service capabilities (kiln rental, etc.)
    func getServiceLocations() async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.hasServices }
    }

    /// Get locations in a specific city
    func getLocations(inCity city: String) async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.city?.lowercased() == city.lowercased() }
    }

    /// Get locations in a specific state
    func getLocations(inState state: String) async throws -> [UnifiedLocationModel] {
        let allLocations = try await repository.fetchAll()
        return allLocations.filter { $0.state?.lowercased() == state.lowercased() }
    }

    // MARK: - Discovery Operations

    /// Get all distinct city names (for autocomplete)
    func getDistinctCities() async throws -> [String] {
        let locations = try await repository.fetchAll()
        let cities = Set(locations.compactMap { $0.city })
        return Array(cities).sorted()
    }

    /// Get all distinct state names (for autocomplete)
    func getDistinctStates() async throws -> [String] {
        let locations = try await repository.fetchAll()
        let states = Set(locations.compactMap { $0.state })
        return Array(states).sorted()
    }

    /// Get all techniques that are available for retail (any location sells)
    func getAvailableRetailTechniques() async throws -> [TechniqueType] {
        let locations = try await repository.fetchAll()
        let techniques = Set(locations.flatMap { $0.retailTechniques })
        return Array(techniques).sorted { $0.displayName < $1.displayName }
    }

    /// Get all techniques that are available for education (any location teaches)
    func getAvailableEducationTechniques() async throws -> [TechniqueType] {
        let locations = try await repository.fetchAll()
        let techniques = Set(locations.flatMap { $0.educationTechniques })
        return Array(techniques).sorted { $0.displayName < $1.displayName }
    }

    /// Get all services that are offered (any location offers)
    func getAvailableServices() async throws -> [ServiceType] {
        let locations = try await repository.fetchAll()
        let services = Set(locations.flatMap { $0.services })
        return Array(services).sorted { $0.displayName < $1.displayName }
    }

    /// Get location count by state
    func getLocationCountByState() async throws -> [String: Int] {
        let locations = try await repository.fetchAll()
        let grouped = Dictionary(grouping: locations) { $0.state ?? "Unknown" }
        return grouped.mapValues { $0.count }
    }

    /// Get location count by city
    func getLocationCountByCity() async throws -> [String: Int] {
        let locations = try await repository.fetchAll()
        let grouped = Dictionary(grouping: locations) { $0.city ?? "Unknown" }
        return grouped.mapValues { $0.count }
    }

    // MARK: - Statistics Operations

    /// Get total number of locations
    func getLocationCount() async throws -> Int {
        return try await repository.count()
    }

    /// Get number of verified locations
    func getVerifiedLocationCount() async throws -> Int {
        let locations = try await repository.fetchAll()
        return locations.filter { $0.isVerified }.count
    }

    /// Get number of locations with valid coordinates
    func getLocationsWithValidCoordinatesCount() async throws -> Int {
        let locations = try await repository.fetchAll()
        return locations.filter { $0.hasValidLocation }.count
    }

    /// Get number of retail locations
    func getRetailLocationCount() async throws -> Int {
        let locations = try await repository.fetchAll()
        return locations.filter { $0.hasRetail }.count
    }

    /// Get number of education locations
    func getEducationLocationCount() async throws -> Int {
        let locations = try await repository.fetchAll()
        return locations.filter { $0.hasEducation }.count
    }

    /// Get number of service locations
    func getServiceLocationCount() async throws -> Int {
        let locations = try await repository.fetchAll()
        return locations.filter { $0.hasServices }.count
    }

    /// Check if a location exists
    func locationExists(withId stable_id: String) async throws -> Bool {
        let location = try await repository.fetch(stableId: stable_id)
        return location != nil
    }

    // MARK: - Convenience Methods

    /// Get locations sorted by distance from a coordinate
    func getLocationsSortedByDistance(from coordinate: CLLocationCoordinate2D) async throws -> [(location: UnifiedLocationModel, distance: CLLocationDistance?)] {
        let locations = try await repository.fetchAll()

        return locations
            .filter { $0.hasValidLocation }
            .map { location in
                (location: location, distance: location.distance(from: coordinate))
            }
            .sorted { pair1, pair2 in
                let dist1 = pair1.distance ?? Double.greatestFiniteMagnitude
                let dist2 = pair2.distance ?? Double.greatestFiniteMagnitude
                return dist1 < dist2
            }
    }

    /// Get the nearest location to a coordinate
    func getNearestLocation(to coordinate: CLLocationCoordinate2D) async throws -> UnifiedLocationModel? {
        let sortedLocations = try await getLocationsSortedByDistance(from: coordinate)
        return sortedLocations.first?.location
    }

    /// Get locations grouped by state
    func getLocationsGroupedByState() async throws -> [String: [UnifiedLocationModel]] {
        let locations = try await repository.fetchAll()
        return Dictionary(grouping: locations) { $0.state ?? "Unknown" }
    }

    /// Get locations grouped by city
    func getLocationsGroupedByCity() async throws -> [String: [UnifiedLocationModel]] {
        let locations = try await repository.fetchAll()
        return Dictionary(grouping: locations) { $0.city ?? "Unknown" }
    }

    /// Get statistics summary for all locations
    func getLocationStatistics() async throws -> LocationStatistics {
        let locations = try await repository.fetchAll()

        return LocationStatistics(
            total: locations.count,
            verified: locations.filter { $0.isVerified }.count,
            withCoordinates: locations.filter { $0.hasValidLocation }.count,
            retail: locations.filter { $0.hasRetail }.count,
            education: locations.filter { $0.hasEducation }.count,
            services: locations.filter { $0.hasServices }.count,
            byState: Dictionary(grouping: locations) { $0.state ?? "Unknown" }.mapValues { $0.count },
            availableRetailTechniques: Set(locations.flatMap { $0.retailTechniques }).count,
            availableEducationTechniques: Set(locations.flatMap { $0.educationTechniques }).count,
            availableServices: Set(locations.flatMap { $0.services }).count
        )
    }

    // MARK: - Data Loading

    /// Load locations from bundle resource (stores.json)
    func loadLocationsFromBundleResource(filename: String = "stores") async throws -> Int {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw UnifiedLocationServiceError.missingRequiredField("stores.json not found in bundle")
        }
        return try await repository.loadLocationsFromJSONFile(at: url)
    }

    /// Load locations from JSON data
    func loadLocationsFromJSON(_ data: Data) async throws -> Int {
        return try await repository.loadLocationsFromJSON(data)
    }

    /// Fetch locations from web URL and merge with existing data (web takes precedence)
    /// - Parameter url: URL to fetch stores.json from (default: https://moltenglass.app/stores.json)
    /// - Returns: Number of locations loaded from web
    func fetchLocationsFromWeb(url: URL = URL(string: "https://moltenglass.app/stores.json")!) async throws -> Int {
        // Fetch JSON from web
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnifiedLocationServiceError.invalidLocation
        }

        guard httpResponse.statusCode == 200 else {
            throw UnifiedLocationServiceError.missingRequiredField("HTTP error \(httpResponse.statusCode)")
        }

        // Load locations from web data
        // The repository will update existing locations with matching stable_id (web takes precedence)
        return try await repository.loadLocationsFromJSON(data)
    }

    /// Load locations with hybrid approach: bundle first, then fetch from web (web wins)
    /// This provides instant offline data while ensuring web is source of truth
    /// - Parameters:
    ///   - bundleFilename: Bundle resource filename (default: "stores")
    ///   - webURL: Web URL to fetch from (default: https://moltenglass.app/stores.json)
    /// - Returns: Tuple of (bundledCount, webCount, totalCount)
    func loadLocationsHybrid(
        bundleFilename: String = "stores",
        webURL: URL = URL(string: "https://moltenglass.app/stores.json")!
    ) async throws -> (bundled: Int, web: Int, total: Int) {
        var bundledCount = 0
        var webCount = 0

        // Step 1: Load bundled locations (offline fallback)
        // Only load if bundle exists - don't fail if missing
        if let bundleURL = Bundle.main.url(forResource: bundleFilename, withExtension: "json") {
            do {
                bundledCount = try await repository.loadLocationsFromJSONFile(at: bundleURL)
                print("✅ Loaded \(bundledCount) locations from app bundle")
            } catch {
                print("⚠️  Failed to load bundled locations: \(error.localizedDescription)")
                // Continue - we'll try web next
            }
        } else {
            print("ℹ️  No bundled stores.json found (this is OK)")
        }

        // Step 2: Fetch from web (source of truth)
        // This runs in background - non-blocking
        do {
            webCount = try await fetchLocationsFromWeb(url: webURL)
            print("✅ Loaded \(webCount) locations from web (overriding any bundled duplicates)")
        } catch {
            print("⚠️  Failed to fetch locations from web: \(error.localizedDescription)")
            // If we have bundled locations, this is OK - offline mode
            if bundledCount == 0 {
                // No bundled locations and web failed - re-throw error
                throw error
            }
        }

        // Get final count
        let totalCount = try await repository.count()

        return (bundled: bundledCount, web: webCount, total: totalCount)
    }
}

// MARK: - Supporting Types

/// Sort options for location lists
enum LocationSortOption: String, Sendable, CaseIterable {
    case name = "Name"
    case city = "City"
    case state = "State"
    case verified = "Verified"
    case distance = "Distance"
    case capabilities = "Capabilities"
}

/// Statistics summary for locations
struct LocationStatistics: Sendable {
    let total: Int
    let verified: Int
    let withCoordinates: Int
    let retail: Int
    let education: Int
    let services: Int
    let byState: [String: Int]
    let availableRetailTechniques: Int
    let availableEducationTechniques: Int
    let availableServices: Int
}

// MARK: - Service Errors

enum UnifiedLocationServiceError: Error, LocalizedError {
    case locationNotFound(String)
    case invalidLocation
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .locationNotFound(let stable_id):
            return "Location not found: \(stable_id)"
        case .invalidLocation:
            return "Invalid location data"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }
}
