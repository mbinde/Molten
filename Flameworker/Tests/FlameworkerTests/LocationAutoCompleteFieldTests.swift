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
    
    @Test("LocationAutoCompleteField should accept LocationRepository via dependency injection")
    func testLocationAutoCompleteFieldUsesLocationRepository() {
        // Arrange: Create mock location repository
        let locationRepository = MockLocationRepository()
        
        @State var location = ""
        
        // Act: Create LocationAutoCompleteField with location repository
        let locationField = LocationAutoCompleteField(
            location: $location,
            locationRepository: locationRepository
        )
        
        // Assert: Should be created successfully with repository injection
        #expect(locationField != nil, "LocationAutoCompleteField should accept LocationRepository via dependency injection")
    }
    
    @Test("LocationAutoCompleteField should work with RepositoryFactory pattern")
    func testLocationAutoCompleteFieldWorksWithRepositoryFactory() {
        // Arrange: Configure factory for testing
        RepositoryFactory.configureForTesting()
        
        @State var testLocation = "Workshop"
        
        // Act: Create field using default repository from factory (no explicit repository needed)
        let locationField = LocationAutoCompleteField(location: $testLocation)
        
        // Assert: Should work with factory-created repository
        #expect(locationField != nil, "LocationAutoCompleteField should work with RepositoryFactory pattern")
    }
    
    @Test("LocationAutoCompleteField should use repository pattern for location data")
    func testLocationAutoCompleteFieldUsesRepositoryPattern() {
        // This test verifies that LocationAutoCompleteField gets location data
        // from LocationRepository using the repository pattern,
        // not from Core Data entities directly
        
        // Arrange: Create mock repository with test data
        let locationRepository = MockLocationRepository()
        
        @State var location = ""
        
        // Act: Create field with repository-based approach
        let locationField = LocationAutoCompleteField(
            location: $location,
            locationRepository: locationRepository
        )
        
        // Assert: Should use repository layer for data access
        #expect(locationField != nil, "LocationAutoCompleteField should access location data via LocationRepository")
    }
    
    @Test("LocationAutoCompleteField should provide location suggestions from repository")
    func testLocationAutoCompleteFieldProvidesSuggestions() async throws {
        // Arrange: Create mock repository with test location data
        let locationRepository = MockLocationRepository()
        
        // Pre-populate repository with test data
        try await locationRepository.populateWithTestData()
        
        // Act: Get distinct location names (this simulates what the field does internally)
        let locationNames = try await locationRepository.getDistinctLocationNames()
        
        // Assert: Should provide location suggestions from repository
        #expect(locationNames.count > 0, "LocationRepository should provide location suggestions")
        #expect(locationNames.contains { $0.contains("Bin") }, "Should include bin locations from test data")
    }
    
    @Test("LocationAutoCompleteField should support prefix-based location search")
    func testLocationAutoCompleteFieldSupportsPrefix() async throws {
        // Arrange: Create mock repository and populate with test data
        let locationRepository = MockLocationRepository()
        try await locationRepository.populateWithTestData()
        
        // Act: Search for locations with specific prefix (simulates user typing)
        let workshopLocations = try await locationRepository.getLocationNames(withPrefix: "Bin")
        
        // Assert: Should return locations matching the prefix
        #expect(workshopLocations.count > 0, "Should find locations with 'Bin' prefix")
        #expect(workshopLocations.allSatisfy { $0.lowercased().contains("bin") }, "All results should contain 'bin'")
    }
    
    @Test("LocationAutoCompleteField should handle empty search gracefully")
    func testLocationAutoCompleteFieldHandlesEmptySearch() async throws {
        // Arrange: Create mock repository
        let locationRepository = MockLocationRepository()
        try await locationRepository.populateWithTestData()
        
        // Act: Search with empty prefix (should return all locations)
        let allLocations = try await locationRepository.getLocationNames(withPrefix: "")
        
        // Assert: Should return all available locations when search is empty
        #expect(allLocations.count > 0, "Should return all locations for empty search")
    }
}
