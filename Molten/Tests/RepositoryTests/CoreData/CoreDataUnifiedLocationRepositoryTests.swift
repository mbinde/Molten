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
struct CoreDataUnifiedLocationRepositoryTests {

    var repository: CoreDataUnifiedLocationRepository

    init() async throws {
        // Create isolated test environment with Core Data
        RepositoryFactory.configureForTestingWithCoreData()
        self.repository = RepositoryFactory.createUnifiedLocationRepository() as! CoreDataUnifiedLocationRepository
    }

    // MARK: - Create Tests

    @Test("Should create location with retail capabilities")
    func testCreateLocationWithRetailCapabilities() async throws {
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
        let created = try await repository.create(location)

        // Assert
        #expect(created.stable_id == "test-store-1")
        #expect(created.name == "Test Glass Store")
        #expect(created.hasRetail == true)
        #expect(created.hasEducation == false)
        #expect(created.retailCapabilities.count == 2)
        #expect(created.supportsFusing == true)
        #expect(created.supportsCasting == true)
    }

    @Test("Should create location with education capabilities")
    func testCreateLocationWithEducationCapabilities() async throws {
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
        let created = try await repository.create(location)

        // Assert
        #expect(created.stable_id == "test-school-1")
        #expect(created.name == "Test Glass School")
        #expect(created.hasRetail == false)
        #expect(created.hasEducation == true)
        #expect(created.educationCapabilities.count == 2)
        #expect(created.supportsGlassBlowing == true)
        #expect(created.supportsFusing == true)
    }

    @Test("Should create location with mixed capabilities")
    func testCreateLocationWithMixedCapabilities() async throws {
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
        let created = try await repository.create(location)

        // Assert
        #expect(created.hasRetail == true)
        #expect(created.hasEducation == true)
        #expect(created.retailCapabilities.count == 1)
        #expect(created.educationCapabilities.count == 1)
    }

    // MARK: - Read Tests

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
        _ = try await repository.create(location)

        // Act
        let fetched = try await repository.fetch(byStableId: "fetch-test-1")

        // Assert
        #expect(fetched != nil)
        #expect(fetched?.name == "Fetch Test Store")
        #expect(fetched?.hasRetail == true)
    }

    @Test("Should return nil for non-existent stable_id")
    func testFetchNonExistentStableId() async throws {
        // Act
        let fetched = try await repository.fetch(byStableId: "does-not-exist")

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
        _ = try await repository.create(location1)
        _ = try await repository.create(location2)

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
        // Arrange
        var location = UnifiedLocationModel(
            stable_id: "update-test-1",
            name: "Update Test Store",
            city: "Seattle",
            state: "WA",
            latitude: 47.6,
            longitude: -122.3,
            isVerified: true,
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )
        location = try await repository.create(location)

        // Act - Add more capabilities
        location = UnifiedLocationModel(
            stable_id: location.stable_id,
            name: location.name,
            city: location.city,
            state: location.state,
            latitude: location.latitude,
            longitude: location.longitude,
            isVerified: location.isVerified,
            retailCapabilities: [
                RetailCapability(technique: .fusing),
                RetailCapability(technique: .casting),
                RetailCapability(technique: .glassBlowing)
            ]
        )
        let updated = try await repository.update(location)

        // Assert
        #expect(updated.retailCapabilities.count == 3)
        #expect(updated.supportsFusing == true)
        #expect(updated.supportsCasting == true)
        #expect(updated.supportsGlassBlowing == true)
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
        _ = try await repository.create(location)

        // Act
        try await repository.delete(byStableId: "delete-test-1")

        // Assert
        let fetched = try await repository.fetch(byStableId: "delete-test-1")
        #expect(fetched == nil)
    }

    // MARK: - Filtering Tests

    @Test("Should filter by technique")
    func testFilterByTechnique() async throws {
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
        _ = try await repository.create(location1)
        _ = try await repository.create(location2)

        // Act
        let fusingLocations = try await repository.fetchAll(supportingTechnique: .fusing)

        // Assert
        #expect(fusingLocations.contains(where: { $0.stable_id == "filter-test-1" }))
        #expect(!fusingLocations.contains(where: { $0.stable_id == "filter-test-2" }))
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
        _ = try await repository.create(location1)
        _ = try await repository.create(location2)

        // Act
        let results = try await repository.search(query: "Bullseye")

        // Assert
        #expect(results.contains(where: { $0.stable_id == "search-test-1" }))
        #expect(!results.contains(where: { $0.stable_id == "search-test-2" }))
    }
}
#endif
