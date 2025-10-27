//
//  MockStoreRepository.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

@preconcurrency import Foundation
import CoreLocation

/// Mock implementation of StoreRepository for testing
/// Provides in-memory storage for store records with realistic behavior
class MockStoreRepository: @unchecked Sendable, StoreRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var stores: [String: StoreModel] = [:]  // Keyed by stable_id
    private let queue = DispatchQueue(label: "mock.store.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    nonisolated(unsafe) var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    nonisolated(unsafe) var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    nonisolated(unsafe) var failureProbability: Double = 0.1

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.stores.removeAll()
        }
    }

    /// Get count of stored stores (for testing)
    nonisolated func getStorageCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.stores.count)
            }
        }
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testStores = [
            StoreModel(
                stable_id: "frantz-art-glass",
                name: "Frantz Art Glass",
                addressLine1: "1222 1st Ave W",
                city: "Seattle",
                state: "WA",
                zip: "98119",
                latitude: 47.6362,
                longitude: -122.3598,
                websiteUrl: "https://frantzartglass.com",
                phone: "(206) 284-5600",
                isVerified: true
            ),
            StoreModel(
                stable_id: "sundance-art-glass",
                name: "Sundance Art Glass",
                addressLine1: "6275 Cullen Blvd",
                city: "Houston",
                state: "TX",
                zip: "77021",
                latitude: 29.6893,
                longitude: -95.3113,
                websiteUrl: "https://www.sundanceartglass.com",
                phone: "(713) 747-8424",
                isVerified: true
            ),
            StoreModel(
                stable_id: "mountain-glass-arts",
                name: "Mountain Glass Arts",
                addressLine1: "3701 Arapahoe Ave",
                city: "Boulder",
                state: "CO",
                zip: "80303",
                latitude: 40.0150,
                longitude: -105.2705,
                websiteUrl: "https://mountainglassarts.com",
                phone: "(303) 449-8737",
                isVerified: true
            )
        ]

        _ = try await createStores(testStores)
    }

    // MARK: - Basic CRUD Operations

    func fetchAllStores() async throws -> [StoreModel] {
        return try await simulateOperation {
            return Array(stores.values).sorted { $0.name < $1.name }
        }
    }

    func fetchStore(byId stable_id: String) async throws -> StoreModel? {
        return try await simulateOperation {
            return stores[stable_id]
        }
    }

    @preconcurrency func fetchStores(matching predicate: NSPredicate?) async throws -> [StoreModel] {
        return try await simulateOperation {
            let allStores = Array(stores.values)

            guard let predicate = predicate else {
                return allStores.sorted { $0.name < $1.name }
            }

            // Simple predicate evaluation for testing
            return allStores.filter { store in
                evaluatePredicate(predicate, for: store)
            }.sorted { $0.name < $1.name }
        }
    }

    func createStore(_ store: StoreModel) async throws -> StoreModel {
        return try await simulateOperation {
            stores[store.stable_id] = store
            return store
        }
    }

    func createStores(_ stores: [StoreModel]) async throws -> [StoreModel] {
        return try await simulateOperation {
            for store in stores {
                self.stores[store.stable_id] = store
            }
            return stores
        }
    }

    func updateStore(_ store: StoreModel) async throws -> StoreModel {
        return try await simulateOperation {
            guard stores[store.stable_id] != nil else {
                throw MockStoreRepositoryError.storeNotFound(store.stable_id)
            }
            stores[store.stable_id] = store
            return store
        }
    }

    func deleteStore(_ store: StoreModel) async throws {
        try await simulateOperation {
            stores.removeValue(forKey: store.stable_id)
        }
    }

    func deleteStore(byId stable_id: String) async throws {
        try await simulateOperation {
            stores.removeValue(forKey: stable_id)
        }
    }

    func deleteAllStores() async throws {
        try await simulateOperation {
            stores.removeAll()
        }
    }

    // MARK: - Query Operations

    func searchStores(matching searchText: String) async throws -> [StoreModel] {
        return try await simulateOperation {
            let lowercaseSearch = searchText.lowercased()
            return stores.values.filter { store in
                store.matchesSearchText(lowercaseSearch)
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchStores(inCity city: String) async throws -> [StoreModel] {
        return try await simulateOperation {
            return stores.values.filter { store in
                store.city?.lowercased() == city.lowercased()
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchStores(inState state: String) async throws -> [StoreModel] {
        return try await simulateOperation {
            return stores.values.filter { store in
                store.state?.lowercased() == state.lowercased()
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchStores(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [StoreModel] {
        return try await simulateOperation {
            let nearbyStores = stores.values.filter { store in
                guard let distance = store.distance(from: coordinate) else { return false }
                return distance <= radiusMeters
            }

            // Sort by distance
            return nearbyStores.sorted { store1, store2 in
                let dist1 = store1.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                let dist2 = store2.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                return dist1 < dist2
            }
        }
    }

    func fetchVerifiedStores() async throws -> [StoreModel] {
        return try await simulateOperation {
            return stores.values.filter { $0.isVerified }.sorted { $0.name < $1.name }
        }
    }

    func fetchStoresWithLocation() async throws -> [StoreModel] {
        return try await simulateOperation {
            return stores.values.filter { $0.hasValidLocation }.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Discovery Operations

    func getDistinctCities() async throws -> [String] {
        return try await simulateOperation {
            let cities = Set(stores.values.compactMap { $0.city })
            return Array(cities).sorted()
        }
    }

    func getDistinctStates() async throws -> [String] {
        return try await simulateOperation {
            let states = Set(stores.values.compactMap { $0.state })
            return Array(states).sorted()
        }
    }

    func getCities(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            let cities = Set(stores.values.compactMap { $0.city })
            return cities.filter { $0.lowercased().hasPrefix(lowercasePrefix) }.sorted()
        }
    }

    func getStates(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            let states = Set(stores.values.compactMap { $0.state })
            return states.filter { $0.lowercased().hasPrefix(lowercasePrefix) }.sorted()
        }
    }

    func getStoreCountByState() async throws -> [String: Int] {
        return try await simulateOperation {
            let stateGroups = Dictionary(grouping: stores.values) { $0.state ?? "Unknown" }
            return stateGroups.mapValues { $0.count }
        }
    }

    func getStoreCountByCity() async throws -> [String: Int] {
        return try await simulateOperation {
            let cityGroups = Dictionary(grouping: stores.values) { $0.city ?? "Unknown" }
            return cityGroups.mapValues { $0.count }
        }
    }

    // MARK: - Bulk Operations

    func loadStoresFromJSON(_ data: Data) async throws -> Int {
        return try await simulateOperation {
            let decoder = JSONDecoder()
            let wrappedData = try decoder.decode(WrappedStoresData.self, from: data)

            var loadedCount = 0
            for storeData in wrappedData.stores {
                let store = storeData.toModel()
                stores[store.stable_id] = store
                loadedCount += 1
            }

            return loadedCount
        }
    }

    func loadStoresFromJSONFile(at fileURL: URL) async throws -> Int {
        return try await simulateOperation {
            let data = try Data(contentsOf: fileURL)
            return try await loadStoresFromJSON(data)
        }
    }

    func exportStoresToJSON() async throws -> Data {
        return try await simulateOperation {
            let allStores = Array(stores.values).sorted { $0.name < $1.name }
            let storeDataArray = allStores.map { $0.toData() }

            let metadata = StoreMetadata(
                version: "1.0",
                generated: ISO8601DateFormatter().string(from: Date()),
                storeCount: storeDataArray.count
            )

            let wrapper = WrappedStoresData(metadata: metadata, stores: storeDataArray)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(wrapper)
        }
    }

    func storeExists(withId stable_id: String) async throws -> Bool {
        return try await simulateOperation {
            return stores[stable_id] != nil
        }
    }

    // MARK: - Statistics Operations

    func getStoreCount() async throws -> Int {
        return try await simulateOperation {
            return stores.count
        }
    }

    func getVerifiedStoreCount() async throws -> Int {
        return try await simulateOperation {
            return stores.values.filter { $0.isVerified }.count
        }
    }

    func getStoresWithLocationCount() async throws -> Int {
        return try await simulateOperation {
            return stores.values.filter { $0.hasValidLocation }.count
        }
    }

    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    nonisolated private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockStoreRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.03) // 10-30ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }

    /// Basic predicate evaluation for testing (supports common patterns)
    nonisolated private func evaluatePredicate(_ predicate: NSPredicate, for store: StoreModel) -> Bool {
        let predicateString = predicate.predicateFormat

        // Handle common predicate patterns
        if predicateString.contains("stable_id ==") {
            if predicateString.contains(store.stable_id) {
                return true
            }
        }

        if predicateString.contains("name ==") || predicateString.contains("name CONTAINS") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let searchTerm = String(afterFirstQuote[..<endRange.lowerBound])
                    if predicateString.contains("CONTAINS") {
                        return store.name.lowercased().contains(searchTerm.lowercased())
                    } else {
                        return store.name == searchTerm
                    }
                }
            }
        }

        if predicateString.contains("city ==") || predicateString.contains("city CONTAINS") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let searchTerm = String(afterFirstQuote[..<endRange.lowerBound])
                    if let city = store.city {
                        if predicateString.contains("CONTAINS") {
                            return city.lowercased().contains(searchTerm.lowercased())
                        } else {
                            return city == searchTerm
                        }
                    }
                    return false
                }
            }
        }

        if predicateString.contains("state ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let searchTerm = String(afterFirstQuote[..<endRange.lowerBound])
                    return store.state == searchTerm
                }
            }
        }

        if predicateString.contains("is_verified == 1") || predicateString.contains("isVerified == 1") {
            return store.isVerified
        }

        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Mock Repository Errors

enum MockStoreRepositoryError: Error, LocalizedError {
    case storeNotFound(String)
    case simulatedFailure
    case invalidJSONData

    var errorDescription: String? {
        switch self {
        case .storeNotFound(let stable_id):
            return "Store not found with ID: \(stable_id)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        case .invalidJSONData:
            return "Invalid JSON data format"
        }
    }
}
