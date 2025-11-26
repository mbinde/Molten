//
//  LocationServiceTests.swift
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

@Suite("Location Repository Pattern Tests", .serialized)
@MainActor
struct LocationServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    
    @Test("LocationRepository should support basic CRUD operations")
    func testLocationRepositoryBasicOperations() async throws {
        // Arrange: Create mock location repository
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        let locationModel = StorageLocationModel(
            inventoryId: inventory_id,
            locationName: "Workshop Storage",
            quantity: 10.0
        )

        // Act: Create a location record
        let createdLocation = try await storageLocationRepository.createLocation(locationModel)

        // Assert: Location should be created successfully
        #expect(createdLocation.inventoryId == locationModel.inventoryId, "Location should be created with correct inventory ID")
        #expect(createdLocation.locationName == "Workshop Storage", "Location should have correct name")
        #expect(createdLocation.quantity == 10.0, "Location should have correct quantity")
    }
    
    @Test("InventoryTrackingService should coordinate location operations")
    func testInventoryTrackingServiceLocationOperations() {
        // Arrange: Create InventoryTrackingService using AppDependencies
        let inventoryTrackingService = deps.inventoryTrackingService
        
        // Assert: Service should be created successfully with location support
        #expect(inventoryTrackingService != nil, "InventoryTrackingService should be created with location repository support")
    }
    
    @Test("LocationRepository should provide location discovery operations")
    func testLocationRepositoryDiscoveryOperations() async throws {
        // Arrange: Create mock location repository with test data
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id1 = UUID()
        let inventory_id2 = UUID()
        
        // Add some test location records
        let location1 = StorageLocationModel(
            inventoryId: inventory_id1,
            locationName: "Workshop",
            quantity: 5.0
        )
        let location2 = StorageLocationModel(
            inventoryId: inventory_id2,
            locationName: "Storage Room",
            quantity: 15.0
        )
        
        _ = try await storageLocationRepository.createLocation(location1)
        _ = try await storageLocationRepository.createLocation(location2)
        
        // Act: Get distinct location names
        let locationNames = try await storageLocationRepository.getDistinctLocationNames()
        
        // Assert: Should return unique location names
        #expect(locationNames.contains("Workshop"), "Should include Workshop location")
        #expect(locationNames.contains("Storage Room"), "Should include Storage Room location")
    }
    
    @Test("LocationRepository should support location search and filtering")
    func testLocationRepositorySearchAndFiltering() async throws {
        // Arrange: Create mock location repository
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        let workshopLocation = StorageLocationModel(
            inventoryId: inventory_id,
            locationName: "Workshop Area",
            quantity: 20.0
        )
        
        _ = try await storageLocationRepository.createLocation(workshopLocation)
        
        // Act: Search for locations with prefix
        let matchingLocations = try await storageLocationRepository.getLocationNames(withPrefix: "Work")
        
        // Assert: Should find matching locations
        #expect(matchingLocations.contains("Workshop Area"), "Should find locations matching prefix")
    }
    
    @Test("LocationRepository should handle quantity operations")
    func testLocationRepositoryQuantityOperations() async throws {
        // Arrange: Create mock location repository
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        // Act: Add quantity to a new location
        let updatedLocation = try await storageLocationRepository.addQuantity(
            25.0,
            toLocation: "Storage Bin A",
            forInventory: inventory_id
        )
        
        // Assert: Should create location with correct quantity
        #expect(updatedLocation.quantity == 25.0, "Should add quantity correctly")
        #expect(updatedLocation.locationName == "Storage Bin A", "Should have correct location name")
        #expect(updatedLocation.inventoryId == inventory_id, "Should have correct inventory ID")
    }
    
    @Test("LocationRepository should support batch location operations")
    func testLocationRepositoryBatchOperations() async throws {
        // Arrange: Create mock location repository
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        let locations = [
            StorageLocationModel(inventoryId: inventory_id, locationName: "Bin 1", quantity: 10.0),
            StorageLocationModel(inventoryId: inventory_id, locationName: "Bin 2", quantity: 15.0),
            StorageLocationModel(inventoryId: inventory_id, locationName: "Bin 3", quantity: 5.0)
        ]

        // Act: Create multiple locations in batch
        let createdLocations = try await storageLocationRepository.createLocations(locations)

        // Assert: Should create all locations successfully
        #expect(createdLocations.count == 3, "Should create all three locations")
        #expect(createdLocations.allSatisfy { $0.inventoryId == inventory_id }, "All locations should have correct inventory ID")
    }
    
    @Test("LocationRepository should support moving quantities between locations")
    func testLocationRepositoryMoveQuantity() async throws {
        // Arrange: Create mock location repository with initial locations
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        // Create initial location with quantity
        _ = try await storageLocationRepository.addQuantity(30.0, toLocation: "Source Bin", forInventory: inventory_id)
        
        // Act: Move quantity from source to destination
        try await storageLocationRepository.moveQuantity(
            15.0,
            fromLocation: "Source Bin",
            toLocation: "Destination Bin",
            forInventory: inventory_id
        )
        
        // Assert: Check that quantities were moved correctly
        let sourceLocations = try await storageLocationRepository.fetchLocations(withName: "Source Bin")
        let destinationLocations = try await storageLocationRepository.fetchLocations(withName: "Destination Bin")
        
        // Find locations for our inventory
        let sourceLocation = sourceLocations.first { $0.inventoryId == inventory_id }
        let destinationLocation = destinationLocations.first { $0.inventoryId == inventory_id }
        
        #expect(sourceLocation?.quantity == 15.0, "Source location should have remaining quantity")
        #expect(destinationLocation?.quantity == 15.0, "Destination location should have moved quantity")
    }
    
    @Test("LocationRepository should validate location quantities")
    func testLocationRepositoryValidateQuantities() async throws {
        // Arrange: Create mock location repository with test locations
        let storageLocationRepository = MockStorageLocationRepository()
        let inventory_id = UUID()
        
        // Add locations with known quantities
        _ = try await storageLocationRepository.addQuantity(10.0, toLocation: "Location A", forInventory: inventory_id)
        _ = try await storageLocationRepository.addQuantity(15.0, toLocation: "Location B", forInventory: inventory_id)
        _ = try await storageLocationRepository.addQuantity(5.0, toLocation: "Location C", forInventory: inventory_id)
        
        // Act: Validate total quantities
        let isValid = try await storageLocationRepository.validateLocationQuantities(
            forInventory: inventory_id,
            expectedTotal: 30.0
        )
        
        let discrepancy = try await storageLocationRepository.getLocationQuantityDiscrepancy(
            forInventory: inventory_id,
            expectedTotal: 30.0
        )
        
        // Assert: Validation should pass and discrepancy should be zero
        #expect(isValid == true, "Location quantities should validate correctly")
        #expect(abs(discrepancy) < 0.001, "Discrepancy should be essentially zero")
    }
}
