//
//  MockUnifiedLocationRepository.swift
//  Molten
//
//  Mock implementation for testing
//

import Foundation

class MockUnifiedLocationRepository: @unchecked Sendable, UnifiedLocationRepository {
    nonisolated(unsafe) private var locations: [String: UnifiedLocationModel] = [:]

    nonisolated init(initialLocations: [UnifiedLocationModel] = []) {
        for location in initialLocations {
            locations[location.stable_id] = location
        }
    }

    func fetchAll() async throws -> [UnifiedLocationModel] {
        return Array(locations.values).sorted { $0.name < $1.name }
    }

    func fetch(stableId: String) async throws -> UnifiedLocationModel? {
        return locations[stableId]
    }

    func save(_ location: UnifiedLocationModel) async throws {
        locations[location.stable_id] = location
    }

    func saveAll(_ locations: [UnifiedLocationModel]) async throws {
        for location in locations {
            try await save(location)
        }
    }

    func delete(stableId: String) async throws {
        locations.removeValue(forKey: stableId)
    }

    func deleteAll() async throws {
        locations.removeAll()
    }

    func search(text: String) async throws -> [UnifiedLocationModel] {
        let lowercaseText = text.lowercased()
        return locations.values.filter { location in
            location.matchesSearchText(lowercaseText)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsSellingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.sells(technique)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsTeachingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.teaches(technique)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsOfferingService(_ service: ServiceType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.offers(service)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsNear(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [UnifiedLocationModel] {
        let radiusDegrees = radiusMeters / 111_000.0

        return locations.values.filter { location in
            let latDiff = abs(location.latitude - latitude)
            let lonDiff = abs(location.longitude - longitude)
            return latDiff < radiusDegrees && lonDiff < radiusDegrees
        }.sorted { $0.name < $1.name }
    }

    func count() async throws -> Int {
        return locations.count
    }
}
