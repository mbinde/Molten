//
//  StoreService.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

import Foundation
import CoreLocation

/// Service layer that handles store business logic using repository pattern
actor StoreService {
    private let repository: StoreRepository

    init(repository: StoreRepository) {
        self.repository = repository
    }

    // MARK: - Basic CRUD Operations

    /// Get all stores
    func getAllStores() async throws -> [StoreModel] {
        return try await repository.fetchAllStores()
    }

    /// Get a single store by stable_id
    func getStore(byId stable_id: String) async throws -> StoreModel? {
        return try await repository.fetchStore(byId: stable_id)
    }

    /// Create a new store
    func createStore(_ store: StoreModel) async throws -> StoreModel {
        return try await repository.createStore(store)
    }

    /// Update an existing store
    func updateStore(_ store: StoreModel) async throws -> StoreModel {
        return try await repository.updateStore(store)
    }

    /// Delete a store
    func deleteStore(_ store: StoreModel) async throws {
        try await repository.deleteStore(store)
    }

    /// Delete a store by stable_id
    func deleteStore(byId stable_id: String) async throws {
        try await repository.deleteStore(byId: stable_id)
    }

    // MARK: - Search & Filter Operations

    /// Search stores by text (name, address, notes)
    func searchStores(searchText: String) async throws -> [StoreModel] {
        return try await repository.searchStores(matching: searchText)
    }

    /// Get stores in a specific city
    func getStores(inCity city: String) async throws -> [StoreModel] {
        return try await repository.fetchStores(inCity: city)
    }

    /// Get stores in a specific state
    func getStores(inState state: String) async throws -> [StoreModel] {
        return try await repository.fetchStores(inState: state)
    }

    /// Get stores near a location
    func getStores(near coordinate: CLLocationCoordinate2D, radiusMeters: Double = 50000) async throws -> [StoreModel] {
        return try await repository.fetchStores(near: coordinate, radiusMeters: radiusMeters)
    }

    /// Get stores near a location (convenience method with miles)
    func getStores(near coordinate: CLLocationCoordinate2D, radiusMiles: Double) async throws -> [StoreModel] {
        let radiusMeters = radiusMiles * 1609.34 // Convert miles to meters
        return try await repository.fetchStores(near: coordinate, radiusMeters: radiusMeters)
    }

    /// Get verified stores only
    func getVerifiedStores() async throws -> [StoreModel] {
        return try await repository.fetchVerifiedStores()
    }

    /// Get stores with valid location data
    func getStoresWithLocation() async throws -> [StoreModel] {
        return try await repository.fetchStoresWithLocation()
    }

    // MARK: - Discovery Operations

    /// Get all distinct city names (for autocomplete)
    func getDistinctCities() async throws -> [String] {
        return try await repository.getDistinctCities()
    }

    /// Get all distinct state names (for autocomplete)
    func getDistinctStates() async throws -> [String] {
        return try await repository.getDistinctStates()
    }

    /// Get cities starting with prefix (for autocomplete)
    func getCities(withPrefix prefix: String) async throws -> [String] {
        return try await repository.getCities(withPrefix: prefix)
    }

    /// Get states starting with prefix (for autocomplete)
    func getStates(withPrefix prefix: String) async throws -> [String] {
        return try await repository.getStates(withPrefix: prefix)
    }

    /// Get store count by state
    func getStoreCountByState() async throws -> [String: Int] {
        return try await repository.getStoreCountByState()
    }

    /// Get store count by city
    func getStoreCountByCity() async throws -> [String: Int] {
        return try await repository.getStoreCountByCity()
    }

    // MARK: - Data Loading Operations

    /// Load stores from JSON data
    func loadStoresFromJSON(_ data: Data) async throws -> Int {
        return try await repository.loadStoresFromJSON(data)
    }

    /// Load stores from JSON file URL
    func loadStoresFromJSONFile(at fileURL: URL) async throws -> Int {
        return try await repository.loadStoresFromJSONFile(at: fileURL)
    }

    /// Load stores from bundle resource
    func loadStoresFromBundleResource(filename: String = "stores") async throws -> Int {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw StoreServiceError.resourceNotFound(filename)
        }
        return try await repository.loadStoresFromJSONFile(at: url)
    }

    /// Fetch stores from web URL and merge with existing data (web takes precedence)
    /// - Parameter url: URL to fetch stores.json from (default: https://moltenglass.app/stores.json)
    /// - Returns: Number of stores loaded from web
    func fetchStoresFromWeb(url: URL = URL(string: "https://moltenglass.app/stores.json")!) async throws -> Int {
        // Fetch JSON from web
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw StoreServiceError.httpError(httpResponse.statusCode)
        }

        // Load stores from web data
        // The repository will update existing stores with matching stable_id (web takes precedence)
        return try await repository.loadStoresFromJSON(data)
    }

    /// Load stores with hybrid approach: bundle first, then fetch from web (web wins)
    /// This provides instant offline data while ensuring web is source of truth
    /// - Parameters:
    ///   - bundleFilename: Bundle resource filename (default: "stores")
    ///   - webURL: Web URL to fetch from (default: https://moltenglass.app/stores.json)
    /// - Returns: Tuple of (bundledCount, webCount, totalCount)
    func loadStoresHybrid(
        bundleFilename: String = "stores",
        webURL: URL = URL(string: "https://moltenglass.app/stores.json")!
    ) async throws -> (bundled: Int, web: Int, total: Int) {
        var bundledCount = 0
        var webCount = 0

        // Step 1: Load bundled stores (offline fallback)
        // Only load if bundle exists - don't fail if missing
        if let bundleURL = Bundle.main.url(forResource: bundleFilename, withExtension: "json") {
            do {
                bundledCount = try await repository.loadStoresFromJSONFile(at: bundleURL)
                print("✅ Loaded \(bundledCount) stores from app bundle")
            } catch {
                print("⚠️  Failed to load bundled stores: \(error.localizedDescription)")
                // Continue - we'll try web next
            }
        } else {
            print("ℹ️  No bundled stores.json found (this is OK)")
        }

        // Step 2: Fetch from web (source of truth)
        // This runs in background - non-blocking
        do {
            webCount = try await fetchStoresFromWeb(url: webURL)
            print("✅ Loaded \(webCount) stores from web (overriding any bundled duplicates)")
        } catch {
            print("⚠️  Failed to fetch stores from web: \(error.localizedDescription)")
            // If we have bundled stores, this is OK - offline mode
            if bundledCount == 0 {
                // No bundled stores and web failed - re-throw error
                throw error
            }
        }

        // Step 3: Get final count
        let totalCount = try await repository.getStoreCount()

        return (bundled: bundledCount, web: webCount, total: totalCount)
    }

    /// Export all stores to JSON data
    func exportStoresToJSON() async throws -> Data {
        return try await repository.exportStoresToJSON()
    }

    // MARK: - Statistics Operations

    /// Get total number of stores
    func getStoreCount() async throws -> Int {
        return try await repository.getStoreCount()
    }

    /// Get number of verified stores
    func getVerifiedStoreCount() async throws -> Int {
        return try await repository.getVerifiedStoreCount()
    }

    /// Get number of stores with valid location data
    func getStoresWithLocationCount() async throws -> Int {
        return try await repository.getStoresWithLocationCount()
    }

    /// Check if a store exists
    func storeExists(withId stable_id: String) async throws -> Bool {
        return try await repository.storeExists(withId: stable_id)
    }

    // MARK: - Convenience Methods

    /// Get stores sorted by distance from a coordinate
    func getStoresSortedByDistance(from coordinate: CLLocationCoordinate2D) async throws -> [(store: StoreModel, distance: CLLocationDistance?)] {
        let stores = try await repository.fetchStoresWithLocation()

        return stores.map { store in
            (store: store, distance: store.distance(from: coordinate))
        }.sorted { pair1, pair2 in
            let dist1 = pair1.distance ?? Double.greatestFiniteMagnitude
            let dist2 = pair2.distance ?? Double.greatestFiniteMagnitude
            return dist1 < dist2
        }
    }

    /// Get the nearest store to a coordinate
    func getNearestStore(to coordinate: CLLocationCoordinate2D) async throws -> StoreModel? {
        let sortedStores = try await getStoresSortedByDistance(from: coordinate)
        return sortedStores.first?.store
    }

    /// Get stores grouped by state
    func getStoresGroupedByState() async throws -> [String: [StoreModel]] {
        let stores = try await repository.fetchAllStores()
        return Dictionary(grouping: stores) { $0.state ?? "Unknown" }
    }

    /// Get stores grouped by city
    func getStoresGroupedByCity() async throws -> [String: [StoreModel]] {
        let stores = try await repository.fetchAllStores()
        return Dictionary(grouping: stores) { $0.city ?? "Unknown" }
    }
}

// MARK: - Supporting Types

/// Sort options for store lists
enum StoreSortOption: String, Sendable, CaseIterable {
    case name = "Name"
    case city = "City"
    case state = "State"
    case verified = "Verified"
    case distance = "Distance"
}

// MARK: - Service Errors

enum StoreServiceError: Error, LocalizedError {
    case resourceNotFound(String)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let filename):
            return "Resource not found in bundle: \(filename)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
