//
//  CoreDataUnifiedLocationRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataUnifiedLocationRepository - manages unified location data
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data UnifiedLocation Repository Tests")
@MainActor
struct CoreDataUnifiedLocationRepositoryTests {

    // MARK: - Create/Save Tests

    @Test("Should save new location")
    func testSaveNewLocation() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let location = UnifiedLocationModel(
            stable_id: "test-loc-1",
            name: "Test Location",
            city: "Seattle",
            state: "WA"
        )

        // Test
        try await repository.save(location)

        // Verify
        let fetched = try await repository.fetch(stableId: "test-loc-1")
        #expect(fetched != nil)
        #expect(fetched?.name == "Test Location")
        #expect(fetched?.city == "Seattle")
    }

    @Test("Should update existing location")
    func testUpdateExistingLocation() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let original = UnifiedLocationModel(
            stable_id: "test-loc-1",
            name: "Original Name",
            city: "Seattle"
        )
        try await repository.save(original)

        // Test
        let updated = UnifiedLocationModel(
            stable_id: "test-loc-1",
            name: "Updated Name",
            city: "Portland"
        )
        try await repository.save(updated)

        // Verify
        let fetched = try await repository.fetch(stableId: "test-loc-1")
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.city == "Portland")
    }

    @Test("Should save multiple locations")
    func testSaveAllLocations() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let locations = [
            UnifiedLocationModel(stable_id: "loc-1", name: "Location 1"),
            UnifiedLocationModel(stable_id: "loc-2", name: "Location 2")
        ]

        // Test
        try await repository.saveAll(locations)

        // Verify
        let count = try await repository.count()
        #expect(count == 2)
    }

    // MARK: - Read Tests

    @Test("Should fetch location by stable_id")
    func testFetchByStableId() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let location = UnifiedLocationModel(
            stable_id: "test-loc-1",
            name: "Test Location"
        )
        try await repository.save(location)

        // Test
        let fetched = try await repository.fetch(stableId: "test-loc-1")

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.stable_id == "test-loc-1")
        #expect(fetched?.name == "Test Location")
    }

    @Test("Should return nil for non-existent location")
    func testFetchNonExistentLocation() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.fetch(stableId: "nonexistent")

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should fetch all locations")
    func testFetchAllLocations() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(stable_id: "loc-1", name: "Location 1"))
        try await repository.save(UnifiedLocationModel(stable_id: "loc-2", name: "Location 2"))

        // Test
        let locations = try await repository.fetchAll()

        // Verify
        #expect(locations.count == 2)
    }

    @Test("Should get location count")
    func testGetCount() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(stable_id: "loc-1", name: "Location 1"))
        try await repository.save(UnifiedLocationModel(stable_id: "loc-2", name: "Location 2"))

        // Test
        let count = try await repository.count()

        // Verify
        #expect(count == 2)
    }

    // MARK: - Search Tests

    @Test("Should search locations by name")
    func testSearchByName() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Seattle Glass Studio"
        ))
        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-2",
            name: "Portland Glass Works"
        ))

        // Test
        let results = try await repository.search(text: "Seattle")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].name == "Seattle Glass Studio")
    }

    @Test("Should search locations by city")
    func testSearchByCity() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Studio 1",
            city: "Seattle"
        ))
        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-2",
            name: "Studio 2",
            city: "Portland"
        ))

        // Test
        let results = try await repository.search(text: "Seattle")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].city == "Seattle")
    }

    @Test("Should search locations by state")
    func testSearchByState() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Studio 1",
            state: "WA"
        ))
        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-2",
            name: "Studio 2",
            state: "OR"
        ))

        // Test
        let results = try await repository.search(text: "WA")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].state == "WA")
    }

    // MARK: - Delete Tests

    @Test("Should delete location by stable_id")
    func testDeleteLocation() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let location = UnifiedLocationModel(
            stable_id: "test-loc-1",
            name: "Test Location"
        )
        try await repository.save(location)

        // Test
        try await repository.delete(stableId: "test-loc-1")

        // Verify
        let fetched = try await repository.fetch(stableId: "test-loc-1")
        #expect(fetched == nil)
    }

    @Test("Should delete all locations")
    func testDeleteAllLocations() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        try await repository.save(UnifiedLocationModel(stable_id: "loc-1", name: "Location 1"))
        try await repository.save(UnifiedLocationModel(stable_id: "loc-2", name: "Location 2"))

        // Test
        try await repository.deleteAll()

        // Verify
        let count = try await repository.count()
        #expect(count == 0)
    }

    // MARK: - Geographic Search Tests

    @Test("Should find locations near coordinates")
    func testFetchLocationsNear() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Seattle coordinates: ~47.6, -122.3
        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-seattle",
            name: "Seattle Studio",
            latitude: 47.6,
            longitude: -122.3
        ))
        // Portland coordinates: ~45.5, -122.7
        try await repository.save(UnifiedLocationModel(
            stable_id: "loc-portland",
            name: "Portland Studio",
            latitude: 45.5,
            longitude: -122.7
        ))

        // Test - search near Seattle (within ~100km)
        let nearSeattle = try await repository.fetchLocationsNear(
            latitude: 47.6,
            longitude: -122.3,
            radiusMeters: 100_000
        )

        // Verify - should find Seattle location
        #expect(nearSeattle.count >= 1)
        #expect(nearSeattle.contains { $0.stable_id == "loc-seattle" })
    }

    // MARK: - Capabilities Tests

    @Test("Should save location with retail capabilities")
    func testSaveWithRetailCapabilities() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let retailCapability = RetailCapability(technique: .fusing, notes: "Full line of fusing supplies")
        let location = UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Test Studio",
            retailCapabilities: [retailCapability]
        )

        // Test
        try await repository.save(location)

        // Verify
        let fetched = try await repository.fetch(stableId: "loc-1")
        #expect(fetched?.retailCapabilities.count == 1)
        #expect(fetched?.retailCapabilities.first?.technique == .fusing)
    }

    @Test("Should save location with education capabilities")
    func testSaveWithEducationCapabilities() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let educationCapability = EducationCapability(
            technique: .glassBlowing,
            classLevel: "Beginner"
        )
        let location = UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Test Studio",
            educationCapabilities: [educationCapability]
        )

        // Test
        try await repository.save(location)

        // Verify
        let fetched = try await repository.fetch(stableId: "loc-1")
        #expect(fetched?.educationCapabilities.count == 1)
        #expect(fetched?.educationCapabilities.first?.technique == .glassBlowing)
    }

    @Test("Should save location with service capabilities")
    func testSaveWithServiceCapabilities() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let serviceCapability = ServicesCapability(
            serviceType: .kilnRental,
            notes: "Available by appointment"
        )
        let location = UnifiedLocationModel(
            stable_id: "loc-1",
            name: "Test Studio",
            servicesCapabilities: [serviceCapability]
        )

        // Test
        try await repository.save(location)

        // Verify
        let fetched = try await repository.fetch(stableId: "loc-1")
        #expect(fetched?.servicesCapabilities.count == 1)
        #expect(fetched?.servicesCapabilities.first?.serviceType == .kilnRental)
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataUnifiedLocationRepository {
        return CoreDataUnifiedLocationRepository(persistenceController: controller)
    }
}
