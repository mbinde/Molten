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
@testable import Flameworker

@Suite("Location Repository Pattern Tests")
struct LocationServiceTests {
    
    @Test("LocationRepository should support basic CRUD operations")
    func testLocationRepositoryBasicOperations() async throws {
        // Arrange: Create mock location repository
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        let locationModel = LocationModel(
            inventoryId: inventoryId,
            location: "Workshop Storage",
            quantity: 10.0
        )
        
        // Act: Create a location record
        let createdLocation = try await locationRepository.createLocation(locationModel)
        
        // Assert: Location should be created successfully
        #expect(createdLocation.inventoryId == locationModel.inventoryId, "Location should be created with correct inventory ID")
        #expect(createdLocation.location == "Workshop Storage", "Location should have correct name")
        #expect(createdLocation.quantity == 10.0, "Location should have correct quantity")
    }
    
    @Test("InventoryTrackingService should coordinate location operations")
    func testInventoryTrackingServiceLocationOperations() {
        // Arrange: Create InventoryTrackingService using RepositoryFactory
        RepositoryFactory.configureForTesting()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Assert: Service should be created successfully with location support
        #expect(inventoryTrackingService != nil, "InventoryTrackingService should be created with location repository support")
    }
    
    @Test("LocationRepository should provide location discovery operations")
    func testLocationRepositoryDiscoveryOperations() async throws {
        // Arrange: Create mock location repository with test data
        let locationRepository = MockLocationRepository()
        let inventoryId1 = UUID()
        let inventoryId2 = UUID()
        
        // Add some test location records
        let location1 = LocationModel(
            inventoryId: inventoryId1,
            location: "Workshop",
            quantity: 5.0
        )
        let location2 = LocationModel(
            inventoryId: inventoryId2,
            location: "Storage Room",
            quantity: 15.0
        )
        
        _ = try await locationRepository.createLocation(location1)
        _ = try await locationRepository.createLocation(location2)
        
        // Act: Get distinct location names
        let locationNames = try await locationRepository.getDistinctLocationNames()
        
        // Assert: Should return unique location names
        #expect(locationNames.contains("Workshop"), "Should include Workshop location")
        #expect(locationNames.contains("Storage Room"), "Should include Storage Room location")
    }
    
    @Test("LocationRepository should support location search and filtering")
    func testLocationRepositorySearchAndFiltering() async throws {
        // Arrange: Create mock location repository
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        let workshopLocation = LocationModel(
            inventoryId: inventoryId,
            location: "Workshop Area",
            quantity: 20.0
        )
        
        _ = try await locationRepository.createLocation(workshopLocation)
        
        // Act: Search for locations with prefix
        let matchingLocations = try await locationRepository.getLocationNames(withPrefix: "Work")
        
        // Assert: Should find matching locations
        #expect(matchingLocations.contains("Workshop Area"), "Should find locations matching prefix")
    }
    
    @Test("LocationRepository should handle quantity operations")
    func testLocationRepositoryQuantityOperations() async throws {
        // Arrange: Create mock location repository
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        // Act: Add quantity to a new location
        let updatedLocation = try await locationRepository.addQuantity(
            25.0,
            toLocation: "Storage Bin A",
            forInventory: inventoryId
        )
        
        // Assert: Should create location with correct quantity
        #expect(updatedLocation.quantity == 25.0, "Should add quantity correctly")
        #expect(updatedLocation.location == "Storage Bin A", "Should have correct location name")
        #expect(updatedLocation.inventoryId == inventoryId, "Should have correct inventory ID")
    }
    
    @Test("LocationRepository should support batch location operations")
    func testLocationRepositoryBatchOperations() async throws {
        // Arrange: Create mock location repository
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        let locations = [
            LocationModel(inventoryId: inventoryId, location: "Bin 1", quantity: 10.0),
            LocationModel(inventoryId: inventoryId, location: "Bin 2", quantity: 15.0),
            LocationModel(inventoryId: inventoryId, location: "Bin 3", quantity: 5.0)
        ]
        
        // Act: Create multiple locations in batch
        let createdLocations = try await locationRepository.createLocations(locations)
        
        // Assert: Should create all locations successfully
        #expect(createdLocations.count == 3, "Should create all three locations")
        #expect(createdLocations.allSatisfy { $0.inventoryId == inventoryId }, "All locations should have correct inventory ID")
    }
    
    @Test("LocationRepository should support moving quantities between locations")
    func testLocationRepositoryMoveQuantity() async throws {
        // Arrange: Create mock location repository with initial locations
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        // Create initial location with quantity
        _ = try await locationRepository.addQuantity(30.0, toLocation: "Source Bin", forInventory: inventoryId)
        
        // Act: Move quantity from source to destination
        try await locationRepository.moveQuantity(
            15.0,
            fromLocation: "Source Bin",
            toLocation: "Destination Bin",
            forInventory: inventoryId
        )
        
        // Assert: Check that quantities were moved correctly
        let sourceLocations = try await locationRepository.fetchLocations(withName: "Source Bin")
        let destinationLocations = try await locationRepository.fetchLocations(withName: "Destination Bin")
        
        // Find locations for our inventory
        let sourceLocation = sourceLocations.first { $0.inventoryId == inventoryId }
        let destinationLocation = destinationLocations.first { $0.inventoryId == inventoryId }
        
        #expect(sourceLocation?.quantity == 15.0, "Source location should have remaining quantity")
        #expect(destinationLocation?.quantity == 15.0, "Destination location should have moved quantity")
    }
    
    @Test("LocationRepository should validate location quantities")
    func testLocationRepositoryValidateQuantities() async throws {
        // Arrange: Create mock location repository with test locations
        let locationRepository = MockLocationRepository()
        let inventoryId = UUID()
        
        // Add locations with known quantities
        _ = try await locationRepository.addQuantity(10.0, toLocation: "Location A", forInventory: inventoryId)
        _ = try await locationRepository.addQuantity(15.0, toLocation: "Location B", forInventory: inventoryId)
        _ = try await locationRepository.addQuantity(5.0, toLocation: "Location C", forInventory: inventoryId)
        
        // Act: Validate total quantities
        let isValid = try await locationRepository.validateLocationQuantities(
            forInventory: inventoryId,
            expectedTotal: 30.0
        )
        
        let discrepancy = try await locationRepository.getLocationQuantityDiscrepancy(
            forInventory: inventoryId,
            expectedTotal: 30.0
        )
        
        // Assert: Validation should pass and discrepancy should be zero
        #expect(isValid == true, "Location quantities should validate correctly")
        #expect(abs(discrepancy) < 0.001, "Discrepancy should be essentially zero")
    }
}
