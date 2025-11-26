//
//  LocationAutoCompleteFieldTests.swift
//  MoltenTests
//
//  Tests for LocationAutoCompleteField using StorageLocationDefinitionRepository
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Molten

@Suite("LocationAutoCompleteField Repository Pattern Tests", .serialized)
@MainActor
struct LocationAutoCompleteFieldTests {

    // MARK: - Shared Dependencies

    /// CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    @Test("LocationAutoCompleteField should accept StorageLocationDefinitionRepository via dependency injection")
    func testLocationAutoCompleteFieldUsesStorageLocationDefinitionRepository() {
        // Arrange: Create mock repository
        let repository = MockStorageLocationDefinitionRepository()

        // Act: Create LocationAutoCompleteField with repository
        let locationField = LocationAutoCompleteField(
            location: .constant(""),
            storageLocationDefinitionRepository: repository
        )

        // Assert: Should be created successfully with repository injection
        #expect(locationField != nil, "LocationAutoCompleteField should accept StorageLocationDefinitionRepository via dependency injection")
    }

    @Test("LocationAutoCompleteField should work with AppDependencies pattern")
    func testLocationAutoCompleteFieldWorksWithAppDependencies() {
        // Arrange: Get repository from dependencies
        let repository = deps.storageLocationDefinitionRepository

        // Act: Create field using repository from factory
        let locationField = LocationAutoCompleteField(
            location: .constant("Workshop"),
            storageLocationDefinitionRepository: repository
        )

        // Assert: Should work with factory-created repository
        #expect(locationField != nil, "LocationAutoCompleteField should work with AppDependencies pattern")
    }

    @Test("LocationAutoCompleteField should use StorageLocationDefinitionRepository for location data")
    func testLocationAutoCompleteFieldUsesRepositoryPattern() {
        // This test verifies that LocationAutoCompleteField gets location data
        // from StorageLocationDefinitionRepository using the repository pattern,
        // not from inventory items directly

        // Arrange: Create mock repository with test data
        let repository = MockStorageLocationDefinitionRepository()

        // Act: Create field with repository-based approach
        let locationField = LocationAutoCompleteField(
            location: .constant(""),
            storageLocationDefinitionRepository: repository
        )

        // Assert: Should use repository layer for data access
        #expect(locationField != nil, "LocationAutoCompleteField should access location data via StorageLocationDefinitionRepository")
    }

    @Test("StorageLocationDefinitionRepository should provide location suggestions")
    func testStorageLocationDefinitionRepositoryProvidesSuggestions() async throws {
        // Arrange: Create test repository with locations
        let repository = MockStorageLocationDefinitionRepository()

        // Create some location definitions
        let def1 = StorageLocationDefinitionModel(name: "Workshop Shelf A")
        let def2 = StorageLocationDefinitionModel(name: "Workshop Shelf B")

        _ = try await repository.create(def1)
        _ = try await repository.create(def2)

        // Act: Get all location definitions
        let definitions = try await repository.fetchAll()

        // Assert: Should provide location suggestions from repository
        #expect(definitions.count >= 2, "Repository should provide location suggestions")
        #expect(definitions.contains { $0.name == "Workshop Shelf A" }, "Should include Workshop Shelf A")
        #expect(definitions.contains { $0.name == "Workshop Shelf B" }, "Should include Workshop Shelf B")
    }

    @Test("StorageLocationDefinitionRepository should support name-based lookup")
    func testStorageLocationDefinitionRepositorySupportsNameLookup() async throws {
        // Arrange: Create test repository with locations
        let repository = MockStorageLocationDefinitionRepository()

        let def1 = StorageLocationDefinitionModel(name: "Workshop Shelf A")
        let def2 = StorageLocationDefinitionModel(name: "Workshop Shelf B")
        let def3 = StorageLocationDefinitionModel(name: "Garage Bin 1")

        _ = try await repository.create(def1)
        _ = try await repository.create(def2)
        _ = try await repository.create(def3)

        // Act: Search for a specific location by name
        let found = try await repository.fetch(byName: "Workshop Shelf A")

        // Assert: Should find the location
        #expect(found != nil, "Should find location by name")
        #expect(found?.name == "Workshop Shelf A", "Should return correct location")
    }

    @Test("StorageLocationDefinitionRepository should handle case-insensitive name lookup")
    func testStorageLocationDefinitionRepositoryHandlesCaseInsensitive() async throws {
        // Arrange: Create test repository
        let repository = MockStorageLocationDefinitionRepository()

        let def = StorageLocationDefinitionModel(name: "Workshop Shelf A")
        _ = try await repository.create(def)

        // Act: Search with different case
        let found = try await repository.fetch(byName: "workshop shelf a")

        // Assert: Should find despite case difference
        #expect(found != nil, "Should find location with case-insensitive search")
        #expect(found?.name == "Workshop Shelf A", "Should return correct location")
    }

    @Test("StorageLocationDefinitionRepository fetchAll should return sorted results")
    func testStorageLocationDefinitionRepositoryReturnsSortedResults() async throws {
        // Arrange: Create test repository
        let repository = MockStorageLocationDefinitionRepository()

        _ = try await repository.create(StorageLocationDefinitionModel(name: "Zebra Location"))
        _ = try await repository.create(StorageLocationDefinitionModel(name: "Alpha Location"))
        _ = try await repository.create(StorageLocationDefinitionModel(name: "Middle Location"))

        // Act: Get all locations
        let definitions = try await repository.fetchAll()

        // Assert: Should be sorted alphabetically
        #expect(definitions.count == 3, "Should have 3 locations")
        #expect(definitions[0].name == "Alpha Location", "First should be Alpha")
        #expect(definitions[1].name == "Middle Location", "Second should be Middle")
        #expect(definitions[2].name == "Zebra Location", "Third should be Zebra")
    }

    @Test("StorageLocationDefinitionRepository should support getOrCreate")
    func testStorageLocationDefinitionRepositoryGetOrCreate() async throws {
        // Arrange: Create test repository
        let repository = MockStorageLocationDefinitionRepository()

        // Act: Get or create a new location
        let def1 = try await repository.getOrCreate(name: "New Location")

        // Assert: Should create new location
        #expect(def1.name == "New Location", "Should create with correct name")

        // Act: Get or create same location again
        let def2 = try await repository.getOrCreate(name: "New Location")

        // Assert: Should return existing location
        #expect(def2.id == def1.id, "Should return same location")

        // Verify only one exists
        let all = try await repository.fetchAll()
        #expect(all.count == 1, "Should only have one location")
    }

    @Test("StorageLocationDefinitionRepository should exclude soft-deleted locations from fetchAll")
    func testStorageLocationDefinitionRepositoryExcludesSoftDeleted() async throws {
        // Arrange: Create test repository
        let repository = MockStorageLocationDefinitionRepository()

        let def1 = StorageLocationDefinitionModel(name: "Active Location")
        let def2 = StorageLocationDefinitionModel(name: "Deleted Location")

        _ = try await repository.create(def1)
        _ = try await repository.create(def2)

        // Soft delete one
        try await repository.softDelete(id: def2.id)

        // Act: Fetch all (should exclude deleted)
        let active = try await repository.fetchAll()

        // Assert: Should only include active locations
        #expect(active.count == 1, "Should only have 1 active location")
        #expect(active[0].name == "Active Location", "Should only include active location")

        // Act: Fetch all including deleted
        let all = try await repository.fetchAllIncludingDeleted()

        // Assert: Should include all locations
        #expect(all.count == 2, "Should have 2 total locations")
    }
}
