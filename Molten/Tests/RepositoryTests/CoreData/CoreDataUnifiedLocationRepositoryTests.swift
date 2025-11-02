//
//  CoreDataUnifiedLocationRepositoryTests.swift
//  RepositoryTests
//
//  Created for unified Locations feature on 11/2/25.
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

/// Tests for CoreDataUnifiedLocationRepository Core Data implementation
@Suite("CoreDataUnifiedLocationRepository Tests")
@MainActor
struct CoreDataUnifiedLocationRepositoryTests {

    let testController: PersistenceController
    let repository: CoreDataUnifiedLocationRepository

    init() async throws {
        // Create isolated test container
        testController = PersistenceController.createTestController()

        // Create repository with test controller
        repository = CoreDataUnifiedLocationRepository(persistenceController: testController)
    }

    // MARK: - Save Tests

    @Test("Should save location with retail capabilities")
    func testSaveLocationWithRetailCapabilities() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "test-store-1",
            name: "Test Glass Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [
                RetailCapability(technique: .fusing),
                RetailCapability(technique: .casting)
            ]
        )

        // Act
        try await repository.save(location)

        // Assert
        let fetched = try await repository.fetch(stableId: "test-store-1")
        #expect(fetched != nil)
        #expect(fetched?.stable_id == "test-store-1")
        #expect(fetched?.name == "Test Glass Store")
        #expect(fetched?.hasRetail == true)
        #expect(fetched?.hasEducation == false)
        #expect(fetched?.retailCapabilities.count == 2)
        #expect(fetched?.supportsFusing == true)
        #expect(fetched?.supportsCasting == true)
    }

    @Test("Should save location with education capabilities")
    func testSaveLocationWithEducationCapabilities() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "test-school-1",
            name: "Test Glass School",
            city: "Stanwood",
            state: "WA",
            latitude: 48.2,
            longitude: -122.4,
            isVerified: true,
            educationCapabilities: [
                EducationCapability(technique: .glassBlowing),
                EducationCapability(technique: .fusing)
            ]
        )

        // Act
        try await repository.save(location)

        // Assert
        let fetched = try await repository.fetch(stableId: "test-school-1")
        #expect(fetched != nil)
        #expect(fetched?.stable_id == "test-school-1")
        #expect(fetched?.name == "Test Glass School")
        #expect(fetched?.hasRetail == false)
        #expect(fetched?.hasEducation == true)
        #expect(fetched?.educationCapabilities.count == 2)
        #expect(fetched?.supportsGlassBlowing == true)
        #expect(fetched?.supportsFusing == true)
    }

    @Test("Should save location with mixed capabilities")
    func testSaveLocationWithMixedCapabilities() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "test-mixed-1",
            name: "Test Studio",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            retailCapabilities: [
                RetailCapability(technique: .fusing)
            ],
            educationCapabilities: [
                EducationCapability(technique: .glassBlowing)
            ]
        )

        // Act
        try await repository.save(location)

        // Assert
        let fetched = try await repository.fetch(stableId: "test-mixed-1")
        #expect(fetched != nil)
        #expect(fetched?.hasRetail == true)
        #expect(fetched?.hasEducation == true)
        #expect(fetched?.retailCapabilities.count == 1)
        #expect(fetched?.educationCapabilities.count == 1)
    }

    // MARK: - Fetch Tests

    @Test("Should fetch location by stable_id")
    func testFetchByStableId() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "fetch-test-1",
            name: "Fetch Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        try await repository.save(location)

        // Act
        let fetched = try await repository.fetch(stableId: "fetch-test-1")

        // Assert
        #expect(fetched != nil)
        #expect(fetched?.name == "Fetch Test Store")
        #expect(fetched?.hasRetail == true)
    }

    @Test("Should return nil for non-existent stable_id")
    func testFetchNonExistentStableId() async throws {
        // Act
        let fetched = try await repository.fetch(stableId: "does-not-exist")

        // Assert
        #expect(fetched == nil)
    }

    @Test("Should fetch all locations")
    func testFetchAll() async throws {
        // Arrange
        let location1 = UnifiedLocationModel(
            stable_id: "all-test-1",
            name: "Store 1",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        let location2 = UnifiedLocationModel(
            stable_id: "all-test-2",
            name: "Store 2",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            educationCapabilities: [EducationCapability(technique: .glassBlowing)]
        )
        try await repository.save(location1)
        try await repository.save(location2)

        // Act
        let all = try await repository.fetchAll()

        // Assert
        #expect(all.count >= 2)
        #expect(all.contains(where: { $0.stable_id == "all-test-1" }))
        #expect(all.contains(where: { $0.stable_id == "all-test-2" }))
    }

    // MARK: - Update Tests

    @Test("Should update location capabilities")
    func testUpdateLocationCapabilities() async throws {
        // Arrange - Save initial location
        let location = UnifiedLocationModel(
            stable_id: "update-test-1",
            name: "Update Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        try await repository.save(location)

        // Act - Update with more capabilities
        let updatedLocation = UnifiedLocationModel(
            stable_id: "update-test-1",
            name: "Update Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [
                RetailCapability(technique: .fusing),
                RetailCapability(technique: .casting),
                RetailCapability(technique: .glassBlowing)
            ]
        )
        try await repository.save(updatedLocation)

        // Assert
        let fetched = try await repository.fetch(stableId: "update-test-1")
        #expect(fetched?.retailCapabilities.count == 3)
        #expect(fetched?.supportsFusing == true)
        #expect(fetched?.supportsCasting == true)
        #expect(fetched?.supportsGlassBlowing == true)
    }

    // MARK: - Delete Tests

    @Test("Should delete location")
    func testDeleteLocation() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "delete-test-1",
            name: "Delete Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        try await repository.save(location)

        // Act
        try await repository.delete(stableId: "delete-test-1")

        // Assert
        let fetched = try await repository.fetch(stableId: "delete-test-1")
        #expect(fetched == nil)
    }

    // MARK: - Filtering Tests

    @Test("Should filter by retail technique")
    func testFilterByRetailTechnique() async throws {
        // Arrange
        let location1 = UnifiedLocationModel(
            stable_id: "filter-test-1",
            name: "Fusing Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        let location2 = UnifiedLocationModel(
            stable_id: "filter-test-2",
            name: "Casting Store",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .casting)]
        )
        try await repository.save(location1)
        try await repository.save(location2)

        // Act
        let fusingLocations = try await repository.fetchLocationsSellingTechnique(.fusing)

        // Assert
        #expect(fusingLocations.contains(where: { $0.stable_id == "filter-test-1" }))
        #expect(!fusingLocations.contains(where: { $0.stable_id == "filter-test-2" }))
    }

    @Test("Should filter by education technique")
    func testFilterByEducationTechnique() async throws {
        // Arrange
        let location1 = UnifiedLocationModel(
            stable_id: "edu-filter-1",
            name: "Glassblowing School",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            educationCapabilities: [EducationCapability(technique: .glassBlowing)]
        )
        let location2 = UnifiedLocationModel(
            stable_id: "edu-filter-2",
            name: "Fusing School",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            educationCapabilities: [EducationCapability(technique: .fusing)]
        )
        try await repository.save(location1)
        try await repository.save(location2)

        // Act
        let glassblowingLocations = try await repository.fetchLocationsTeachingTechnique(.glassBlowing)

        // Assert
        #expect(glassblowingLocations.contains(where: { $0.stable_id == "edu-filter-1" }))
        #expect(!glassblowingLocations.contains(where: { $0.stable_id == "edu-filter-2" }))
    }

    @Test("Should search by name")
    func testSearchByName() async throws {
        // Arrange
        let location1 = UnifiedLocationModel(
            stable_id: "search-test-1",
            name: "Bullseye Glass",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        let location2 = UnifiedLocationModel(
            stable_id: "search-test-2",
            name: "Spectrum Glass",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .casting)]
        )
        try await repository.save(location1)
        try await repository.save(location2)

        // Act
        let results = try await repository.search(text: "Bullseye")

        // Assert
        #expect(results.contains(where: { $0.stable_id == "search-test-1" }))
        #expect(!results.contains(where: { $0.stable_id == "search-test-2" }))
    }

    // MARK: - Count Tests

    @Test("Should count locations")
    func testCountLocations() async throws {
        // Arrange
        let location1 = UnifiedLocationModel(
            stable_id: "count-test-1",
            name: "Store 1",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        let location2 = UnifiedLocationModel(
            stable_id: "count-test-2",
            name: "Store 2",
            city: "Portland",
            state: "OR",
            latitude: 45.5,
            longitude: -122.6,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .casting)]
        )
        try await repository.save(location1)
        try await repository.save(location2)

        // Act
        let count = try await repository.count()

        // Assert
        #expect(count >= 2)
    }

    // MARK: - DeleteAll Tests

    @Test("Should delete all locations")
    func testDeleteAll() async throws {
        // Arrange
        let location = UnifiedLocationModel(
            stable_id: "deleteall-test-1",
            name: "Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        try await repository.save(location)

        // Act
        try await repository.deleteAll()

        // Assert
        let count = try await repository.count()
        #expect(count == 0)
    }
}
#endif
