//
//  CatalogViewCOEIntegrationTests.swift
//  FlameworkerTests
//
//  Tests for COE filter integration in CatalogView
//  Created by TDD on 10/5/25.
//

import Testing
@testable import Flameworker

@Suite("CatalogView COE Integration Tests")
struct CatalogViewCOEIntegrationTests {
    
    @Test("Should apply COE filter first in CatalogView filter chain")
    func testCOEFilterFirstInChain() {
        // Test that CatalogView applies COE filter before other filters
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Create test data
            let mockItems = [
                MockCatalogItem(manufacturer: "EF", name: "Effetre Red", tags: "transparent"),      // COE 104
                MockCatalogItem(manufacturer: "BB", name: "Boro Clear", tags: "transparent"),       // COE 33
                MockCatalogItem(manufacturer: "EF", name: "Effetre Blue", tags: "opaque")          // COE 104
            ]
            
            // Create isolated test UserDefaults
            let testSuite = "CatalogViewIntegration_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            
            // Set COE 104 preference
            COEGlassPreference.setCOEFilter(.coe104)
            
            // Test complete filter chain: COE → Tags → Search
            let coeFiltered = CatalogViewIntegration.applyAllFilters(
                items: mockItems,
                selectedTags: Set(["transparent"]),
                searchText: ""
            )
            
            #expect(coeFiltered.count == 1, "Should return 1 item after COE and tag filters")
            #expect(coeFiltered.first?.name == "Effetre Red", "Should return transparent COE 104 item")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // When feature disabled, COE filter should be skipped
            let mockItems = [MockCatalogItem(manufacturer: "EF", name: "Test")]
            let filtered = CatalogViewIntegration.applyAllFilters(
                items: mockItems,
                selectedTags: Set(),
                searchText: ""
            )
            #expect(filtered.count == 1, "Should return all items when feature disabled")
        }
    }
    
    @Test("Should integrate COE filter with existing CatalogView state")
    func testCOEFilterWithCatalogViewState() {
        // Test COE filter integration with CatalogView's existing filtering system
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            let mockItems = [
                MockCatalogItem(manufacturer: "BB", name: "Boro Batch Clear"), // COE 33
                MockCatalogItem(manufacturer: "BE", name: "Bullseye Red"),      // COE 90
                MockCatalogItem(manufacturer: "EF", name: "Effetre Blue")      // COE 104
            ]
            
            // Create isolated test UserDefaults
            let testSuite = "CatalogViewState_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            
            // Test with no COE preference - should return all enabled manufacturers
            COEGlassPreference.resetToDefault()
            let allManufacturers = Set(["BB", "BE", "EF"])
            let unfilteredResult = CatalogViewIntegration.applyManufacturerAndCOEFilters(
                items: mockItems,
                enabledManufacturers: allManufacturers
            )
            #expect(unfilteredResult.count == 3, "Should return all items with no COE filter")
            
            // Test with COE 33 preference - should only return COE 33 items
            COEGlassPreference.setCOEFilter(.coe33)
            let coe33Result = CatalogViewIntegration.applyManufacturerAndCOEFilters(
                items: mockItems,
                enabledManufacturers: allManufacturers
            )
            #expect(coe33Result.count == 1, "Should return only COE 33 items")
            #expect(coe33Result.first?.manufacturer == "BB", "Should return Boro Batch item")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // Feature disabled test
            #expect(true, "COE integration not tested when feature disabled")
        }
    }
    
    @Test("Should preserve existing CatalogView functionality when COE disabled")
    func testExistingFunctionalityPreserved() {
        // Verify that existing CatalogView filtering still works when COE feature is off
        let mockItems = [
            MockCatalogItem(manufacturer: "EF", name: "Effetre Red", tags: "transparent"),
            MockCatalogItem(manufacturer: "BB", name: "Boro Blue", tags: "opaque")
        ]
        
        // Test manufacturer filtering still works
        let enabledManufacturers = Set(["EF"])
        let manufacturerFiltered = CatalogViewIntegration.applyManufacturerAndCOEFilters(
            items: mockItems,
            enabledManufacturers: enabledManufacturers
        )
        #expect(manufacturerFiltered.count == 1, "Manufacturer filtering should still work")
        #expect(manufacturerFiltered.first?.manufacturer == "EF", "Should filter by manufacturer")
        
        // Test tag filtering still works
        let tagFiltered = CatalogViewIntegration.applyAllFilters(
            items: mockItems,
            selectedTags: Set(["transparent"]),
            searchText: ""
        )
        #expect(tagFiltered.count == 1, "Tag filtering should still work")
        #expect(tagFiltered.first?.tags == "transparent", "Should filter by tags")
    }
}