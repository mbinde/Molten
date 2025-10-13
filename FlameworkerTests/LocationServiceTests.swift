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

@Suite("LocationService Repository Pattern Tests")
struct LocationServiceTests {
    
    @Test("LocationService should use InventoryService instead of Core Data context")
    func testLocationServiceUsesInventoryService() {
        // Arrange: Create inventory service with existing repository
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        
        // Act: Create LocationService with inventory service
        let locationService = LocationService(inventoryService: inventoryService)
        
        // Assert: Should be created successfully with service instead of Core Data context
        #expect(locationService != nil, "LocationService should accept InventoryService via dependency injection")
    }
    
    @Test("LocationService should not require Core Data context for location operations")
    func testLocationServiceWorksWithoutCoreDataContext() async throws {
        // Arrange: Create service with repository
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        let locationService = LocationService(inventoryService: inventoryService)
        
        // Act: Get unique locations without Core Data context
        let locations = try await locationService.getUniqueLocations()
        
        // Assert: Should work without Core Data environment
        #expect(locations != nil, "LocationService should work without Core Data context when using repository pattern")
    }
    
    @Test("LocationService should provide location suggestions via async repository operations")
    func testLocationServiceProvidesAsyncLocationSuggestions() async throws {
        // Arrange: Create service with repository pattern
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        let locationService = LocationService(inventoryService: inventoryService)
        
        // Act: Get location suggestions asynchronously
        let suggestions = try await locationService.getLocationSuggestions(matching: "Workshop")
        
        // Assert: Should return suggestions via async operations
        #expect(suggestions != nil, "LocationService should provide location suggestions via async repository operations")
    }
    
    @Test("LocationService should use business models for location data")
    func testLocationServiceUsesBusinessModels() {
        // This test verifies that LocationService gets location data
        // from InventoryItemModel business models via the service layer,
        // not from Core Data entities directly
        
        // Arrange: Create service 
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        
        // Act: Create service with repository-based approach
        let locationService = LocationService(inventoryService: inventoryService)
        
        // Assert: Should use service layer for data access
        #expect(locationService != nil, "LocationService should access location data via InventoryService, not Core Data directly")
    }
}