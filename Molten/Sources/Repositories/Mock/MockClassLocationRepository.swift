//
//  MockClassLocationRepository.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

@preconcurrency import Foundation
import CoreLocation

/// Mock implementation of ClassLocationRepository for testing
/// Provides in-memory storage for classLocation records with realistic behavior
class MockClassLocationRepository: @unchecked Sendable, ClassLocationRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var classLocations: [String: ClassLocationModel] = [:]  // Keyed by stable_id
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

    /// Clear all classLocationd data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.classLocations.removeAll()
        }
    }

    /// Get count of classLocationd classLocations (for testing)
    nonisolated func getStorageCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.classLocations.count)
            }
        }
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testStores = [
            ClassLocationModel(
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
            ClassLocationModel(
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
            ClassLocationModel(
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

        _ = try await createClassLocations(testStores)
    }

    // MARK: - Basic CRUD Operations

    func fetchAllClassLocations() async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return Array(classLocations.values).sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocation(byId stable_id: String) async throws -> ClassLocationModel? {
        return try await simulateOperation {
            return classLocations[stable_id]
        }
    }

    @preconcurrency func fetchClassLocations(matching predicate: NSPredicate?) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            let allStores = Array(classLocations.values)

            guard let predicate = predicate else {
                return allStores.sorted { $0.name < $1.name }
            }

            // Simple predicate evaluation for testing
            return allStores.filter { classLocation in
                evaluatePredicate(predicate, for: classLocation)
            }.sorted { $0.name < $1.name }
        }
    }

    func createClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel {
        return try await simulateOperation {
            classLocations[classLocation.stable_id] = classLocation
            return classLocation
        }
    }

    func createClassLocations(_ classLocations: [ClassLocationModel]) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            for classLocation in classLocations {
                self.classLocations[classLocation.stable_id] = classLocation
            }
            return classLocations
        }
    }

    func updateClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel {
        return try await simulateOperation {
            guard classLocations[classLocation.stable_id] != nil else {
                throw MockClassLocationRepositoryError.classLocationNotFound(classLocation.stable_id)
            }
            classLocations[classLocation.stable_id] = classLocation
            return classLocation
        }
    }

    func deleteClassLocation(_ classLocation: ClassLocationModel) async throws {
        try await simulateOperation {
            classLocations.removeValue(forKey: classLocation.stable_id)
        }
    }

    func deleteClassLocation(byId stable_id: String) async throws {
        try await simulateOperation {
            classLocations.removeValue(forKey: stable_id)
        }
    }

    func deleteAllClassLocations() async throws {
        try await simulateOperation {
            classLocations.removeAll()
        }
    }

    // MARK: - Query Operations

    func searchClassLocations(matching searchText: String) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            let lowercaseSearch = searchText.lowercased()
            return classLocations.values.filter { classLocation in
                classLocation.matchesSearchText(lowercaseSearch)
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(inCity city: String) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return classLocations.values.filter { classLocation in
                classLocation.city?.lowercased() == city.lowercased()
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(inState state: String) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return classLocations.values.filter { classLocation in
                classLocation.state?.lowercased() == state.lowercased()
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            let nearbyStores = classLocations.values.filter { classLocation in
                guard let distance = classLocation.distance(from: coordinate) else { return false }
                return distance <= radiusMeters
            }

            // Sort by distance
            return nearbyStores.sorted { classLocation1, classLocation2 in
                let dist1 = classLocation1.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                let dist2 = classLocation2.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                return dist1 < dist2
            }
        }
    }

    func fetchVerifiedClassLocations() async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return classLocations.values.filter { $0.isVerified }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocationsWithLocation() async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return classLocations.values.filter { $0.hasValidLocation }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(supportingTechnique technique: TechniqueType) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            return classLocations.values.filter { $0.supportsTechnique(technique) }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(supportingAnyOf techniques: [TechniqueType]) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            guard !techniques.isEmpty else { return [] }
            return classLocations.values.filter { classLocation in
                techniques.contains(where: { classLocation.supportsTechnique($0) })
            }.sorted { $0.name < $1.name }
        }
    }

    func fetchClassLocations(supportingAllOf techniques: [TechniqueType]) async throws -> [ClassLocationModel] {
        return try await simulateOperation {
            guard !techniques.isEmpty else { return [] }
            return classLocations.values.filter { classLocation in
                techniques.allSatisfy { classLocation.supportsTechnique($0) }
            }.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Discovery Operations

    func getDistinctCities() async throws -> [String] {
        return try await simulateOperation {
            let cities = Set(classLocations.values.compactMap { $0.city })
            return Array(cities).sorted()
        }
    }

    func getDistinctStates() async throws -> [String] {
        return try await simulateOperation {
            let states = Set(classLocations.values.compactMap { $0.state })
            return Array(states).sorted()
        }
    }

    func getCities(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            let cities = Set(classLocations.values.compactMap { $0.city })
            return cities.filter { $0.lowercased().hasPrefix(lowercasePrefix) }.sorted()
        }
    }

    func getStates(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            let states = Set(classLocations.values.compactMap { $0.state })
            return states.filter { $0.lowercased().hasPrefix(lowercasePrefix) }.sorted()
        }
    }

    func getClassLocationCountByState() async throws -> [String: Int] {
        return try await simulateOperation {
            let stateGroups = Dictionary(grouping: classLocations.values) { $0.state ?? "Unknown" }
            return stateGroups.mapValues { $0.count }
        }
    }

    func getClassLocationCountByCity() async throws -> [String: Int] {
        return try await simulateOperation {
            let cityGroups = Dictionary(grouping: classLocations.values) { $0.city ?? "Unknown" }
            return cityGroups.mapValues { $0.count }
        }
    }

    // MARK: - Bulk Operations

    func loadClassLocationsFromJSON(_ data: Data) async throws -> Int {
        return try await simulateOperation {
            // TODO: Implement ClassLocationData JSON structure
            // Currently using mock data instead of JSON deserialization
            return 0
        }
    }

    func loadClassLocationsFromJSONFile(at fileURL: URL) async throws -> Int {
        return try await simulateOperation {
            let data = try Data(contentsOf: fileURL)
            return try await loadClassLocationsFromJSON(data)
        }
    }

    func exportClassLocationsToJSON() async throws -> Data {
        return try await simulateOperation {
            // TODO: Implement ClassLocationData JSON structure
            // Currently returning empty JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let emptyArray: [String] = []
            return try encoder.encode(["classLocations": emptyArray])
        }
    }

    func classLocationExists(withId stable_id: String) async throws -> Bool {
        return try await simulateOperation {
            return classLocations[stable_id] != nil
        }
    }

    // MARK: - Statistics Operations

    func getClassLocationCount() async throws -> Int {
        return try await simulateOperation {
            return classLocations.count
        }
    }

    func getVerifiedClassLocationCount() async throws -> Int {
        return try await simulateOperation {
            return classLocations.values.filter { $0.isVerified }.count
        }
    }

    func getClassLocationsWithLocationCount() async throws -> Int {
        return try await simulateOperation {
            return classLocations.values.filter { $0.hasValidLocation }.count
        }
    }

    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    nonisolated private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockClassLocationRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.03) // 10-30ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }

    /// Basic predicate evaluation for testing (supports common patterns)
    nonisolated private func evaluatePredicate(_ predicate: NSPredicate, for classLocation: ClassLocationModel) -> Bool {
        let predicateString = predicate.predicateFormat

        // Handle common predicate patterns
        if predicateString.contains("stable_id ==") {
            if predicateString.contains(classLocation.stable_id) {
                return true
            }
        }

        if predicateString.contains("name ==") || predicateString.contains("name CONTAINS") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let searchTerm = String(afterFirstQuote[..<endRange.lowerBound])
                    if predicateString.contains("CONTAINS") {
                        return classLocation.name.lowercased().contains(searchTerm.lowercased())
                    } else {
                        return classLocation.name == searchTerm
                    }
                }
            }
        }

        if predicateString.contains("city ==") || predicateString.contains("city CONTAINS") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let searchTerm = String(afterFirstQuote[..<endRange.lowerBound])
                    if let city = classLocation.city {
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
                    return classLocation.state == searchTerm
                }
            }
        }

        if predicateString.contains("is_verified == 1") || predicateString.contains("isVerified == 1") {
            return classLocation.isVerified
        }

        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Mock Repository Errors

enum MockClassLocationRepositoryError: Error, LocalizedError {
    case classLocationNotFound(String)
    case simulatedFailure
    case invalidJSONData

    var errorDescription: String? {
        switch self {
        case .classLocationNotFound(let stable_id):
            return "Store not found with ID: \(stable_id)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        case .invalidJSONData:
            return "Invalid JSON data format"
        }
    }
}
