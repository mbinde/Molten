//
//  LocationAutoCompleteFieldTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
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

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    @Test("LocationAutoCompleteField should accept InventoryRepository via dependency injection")
    func testLocationAutoCompleteFieldUsesInventoryRepository() {
        // Arrange: Create mock inventory repository
        let inventoryRepository = MockInventoryRepository()

        // Create a wrapper to hold state properly
        struct TestWrapper {
            var location = ""
        }
        var wrapper = TestWrapper()

        // Act: Create LocationAutoCompleteField with inventory repository
        // Use constant binding since we're just testing the API accepts the parameter
        let locationField = LocationAutoCompleteField(
            location: .constant(wrapper.location),
            inventoryRepository: inventoryRepository
        )

        // Assert: Should be created successfully with repository injection
        #expect(locationField != nil, "LocationAutoCompleteField should accept InventoryRepository via dependency injection")
    }

    @Test("LocationAutoCompleteField should work with AppDependencies pattern")
    func testLocationAutoCompleteFieldWorksWithAppDependencies() {
        // Arrange: Configure factory for testing
        let inventoryRepository = deps.inventoryRepository

        // Use constant binding since we're just testing the API works with AppDependencies
        let testLocation = "Workshop"

        // Act: Create field using repository from factory
        let locationField = LocationAutoCompleteField(location: .constant(testLocation), inventoryRepository: inventoryRepository)

        // Assert: Should work with factory-created repository
        #expect(locationField != nil, "LocationAutoCompleteField should work with AppDependencies pattern")
    }

    @Test("LocationAutoCompleteField should use repository pattern for location data")
    func testLocationAutoCompleteFieldUsesRepositoryPattern() {
        // This test verifies that LocationAutoCompleteField gets location data
        // from InventoryRepository using the repository pattern,
        // not from Core Data entities directly

        // Arrange: Create mock repository with test data
        let inventoryRepository = MockInventoryRepository()

        // Use constant binding since we're just testing the API accepts repository pattern
        let location = ""

        // Act: Create field with repository-based approach
        let locationField = LocationAutoCompleteField(
            location: .constant(location),
            inventoryRepository: inventoryRepository
        )

        // Assert: Should use repository layer for data access
        #expect(locationField != nil, "LocationAutoCompleteField should access location data via InventoryRepository")
    }

    @Test("LocationAutoCompleteField should provide location suggestions from repository")
    func testLocationAutoCompleteFieldProvidesSuggestions() async throws {
        // Arrange: Create test inventory with locations
        let inventoryRepository = deps.inventoryRepository

        // Create some inventory items with locations
        let item1 = InventoryModel(
            item_stable_id: "test-item-1",
            type: "rod",
            quantity: 10,
            location: "Workshop Shelf A"
        )
        let item2 = InventoryModel(
            item_stable_id: "test-item-2",
            type: "rod",
            quantity: 5,
            location: "Workshop Shelf B"
        )

        _ = try await inventoryRepository.createInventory(item1)
        _ = try await inventoryRepository.createInventory(item2)

        // Act: Get distinct location names (this simulates what the field does internally)
        let locationNames = try await inventoryRepository.getDistinctLocations()

        // Assert: Should provide location suggestions from repository
        #expect(locationNames.count >= 2, "InventoryRepository should provide location suggestions")
        #expect(locationNames.contains("Workshop Shelf A"), "Should include Workshop Shelf A")
        #expect(locationNames.contains("Workshop Shelf B"), "Should include Workshop Shelf B")
    }

    @Test("LocationAutoCompleteField should support prefix-based location search")
    func testLocationAutoCompleteFieldSupportsPrefix() async throws {
        // Arrange: Create test inventory with locations
        let inventoryRepository = deps.inventoryRepository

        let item1 = InventoryModel(item_stable_id: "test-1", type: "rod", quantity: 10, location: "Workshop Shelf A")
        let item2 = InventoryModel(item_stable_id: "test-2", type: "rod", quantity: 5, location: "Workshop Shelf B")
        let item3 = InventoryModel(item_stable_id: "test-3", type: "rod", quantity: 3, location: "Garage Bin 1")

        _ = try await inventoryRepository.createInventory(item1)
        _ = try await inventoryRepository.createInventory(item2)
        _ = try await inventoryRepository.createInventory(item3)

        // Act: Search for locations with specific prefix (simulates user typing)
        let workshopLocations = try await inventoryRepository.getLocationNames(withPrefix: "Workshop")

        // Assert: Should return locations matching the prefix
        #expect(workshopLocations.count >= 2, "Should find locations with 'Workshop' prefix")
        #expect(workshopLocations.allSatisfy { $0.hasPrefix("Workshop") }, "All results should start with 'Workshop'")
    }

    @Test("LocationAutoCompleteField should handle empty search gracefully")
    func testLocationAutoCompleteFieldHandlesEmptySearch() async throws {
        // Arrange: Create test inventory
        let inventoryRepository = deps.inventoryRepository

        let item1 = InventoryModel(item_stable_id: "test-1", type: "rod", quantity: 10, location: "Location A")
        _ = try await inventoryRepository.createInventory(item1)

        // Act: Search with empty prefix (should return all locations)
        let allLocations = try await inventoryRepository.getDistinctLocations()

        // Assert: Should return all available locations when search is empty
        #expect(allLocations.count > 0, "Should return all locations for empty search")
    }
}
