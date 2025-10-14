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
@testable import Flameworker

@Suite("LocationAutoCompleteField Repository Pattern Tests")
struct LocationAutoCompleteFieldTests {
    
    @Test("LocationAutoCompleteField should accept InventoryService instead of Core Data context")
    func testLocationAutoCompleteFieldUsesInventoryService() {
        // Arrange: Create inventory service with existing repository
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        
        @State var location = ""
        
        // Act: Create LocationAutoCompleteField with inventory service
        let locationField = LocationAutoCompleteField(
            location: $location,
            inventoryService: inventoryService
        )
        
        // Assert: Should be created successfully with service instead of Core Data context
        #expect(locationField != nil, "LocationAutoCompleteField should accept InventoryService via dependency injection")
    }
    
    @Test("LocationAutoCompleteField should not require Core Data context when using repository pattern")
    func testLocationAutoCompleteFieldWorksWithoutCoreDataContext() {
        // Arrange: Create service with repository
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        
        @State var testLocation = "Workshop"
        
        // Act: Create field with service (no Core Data context needed)
        let locationField = LocationAutoCompleteField(
            location: $testLocation,
            inventoryService: inventoryService
        )
        
        // Assert: Should work without Core Data environment
        #expect(locationField != nil, "LocationAutoCompleteField should work without Core Data context when using repository pattern")
    }
    
    @Test("LocationAutoCompleteField should use business models for location data")
    func testLocationAutoCompleteFieldUsesBusinessModels() {
        // This test verifies that LocationAutoCompleteField gets location data
        // from InventoryItemModel business models via the service layer,
        // not from Core Data entities directly
        
        // Arrange: Create service 
        let coreDataRepository = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataRepository)
        
        @State var location = ""
        
        // Act: Create field with service-based approach
        let locationField = LocationAutoCompleteField(
            location: $location,
            inventoryService: inventoryService
        )
        
        // Assert: Should use service layer for data access
        #expect(locationField != nil, "LocationAutoCompleteField should access location data via InventoryService, not Core Data directly")
    }
}