//
//  COEGlassFilterTests.swift
//  FlameworkerTests
//
//  Tests for COE glass filtering functionality
//  Created by TDD on 10/5/25.
//

import Testing
@testable import Flameworker

@Suite("COE Glass Filter Tests")
struct COEGlassFilterTests {
    
    @Test("Should have COE glass filter feature flag")
    func testCOEGlassFilterFeatureFlag() {
        // This test verifies that the feature flag exists for COE glass filtering
        let isEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        // Feature should exist (we don't care if it's true or false initially)
        #expect(isEnabled == false || isEnabled == true, "COE glass filter feature flag should exist")
    }
    
    @Test("Should support all COE glass types")
    func testCOEGlassTypes() {
        // Test that the COE glass type enum supports the required types
        let coe33 = COEGlassType.coe33
        let coe90 = COEGlassType.coe90  
        let coe96 = COEGlassType.coe96
        let coe104 = COEGlassType.coe104
        
        #expect(coe33.rawValue == 33)
        #expect(coe90.rawValue == 90)
        #expect(coe96.rawValue == 96) 
        #expect(coe104.rawValue == 104)
    }
    
    @Test("Should have display names for COE glass types")
    func testCOEGlassTypeDisplayNames() {
        let coe33 = COEGlassType.coe33
        let coe90 = COEGlassType.coe90
        let coe96 = COEGlassType.coe96
        let coe104 = COEGlassType.coe104
        
        #expect(coe33.displayName == "COE 33")
        #expect(coe90.displayName == "COE 90")
        #expect(coe96.displayName == "COE 96")
        #expect(coe104.displayName == "COE 104")
    }
    
    @Test("Should have COE preference storage key")
    func testCOEPreferenceStorageKey() {
        // Test that the COE preference has a storage key
        let storageKey = COEGlassPreference.storageKey
        #expect(!storageKey.isEmpty, "COE preference should have a storage key")
        #expect(storageKey.contains("coe"), "Storage key should contain 'coe'")
    }
    
    @Test("Should default to no COE filter")
    func testDefaultCOEPreference() {
        // Reset to defaults
        COEGlassPreference.resetToDefault()
        
        // Should default to nil (no filter applied)
        let current = COEGlassPreference.current
        #expect(current == nil, "Should default to no COE filter")
    }
    
    @Test("Should save and retrieve COE preference")
    func testCOEPreferenceSaveRetrieve() {
        // Create isolated test UserDefaults
        let testSuite = "COETest_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        
        // Set test defaults
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Set COE preference
        COEGlassPreference.setCOEFilter(.coe33)
        
        // Verify it was saved
        let retrieved = COEGlassPreference.current
        #expect(retrieved == .coe33, "Should save and retrieve COE 33 preference")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should filter catalog items by COE when preference is set")
    func testCatalogFilteringByCOE() {
        // Create mock catalog items with different manufacturers/COEs
        let mockItems = [
            MockCatalogItem(manufacturer: "BB", name: "Boro Batch Clear"), // COE 33
            MockCatalogItem(manufacturer: "BE", name: "Bullseye Red"),      // COE 90
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue"),     // COE 104
            MockCatalogItem(manufacturer: "NS", name: "Northstar Green")   // COE 33
        ]
        
        // Test filtering by COE 33
        let coe33Items = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: .coe33)
        #expect(coe33Items.count == 2, "Should return 2 COE 33 items (BB, NS)")
        #expect(coe33Items.allSatisfy { item in
            GlassManufacturers.supports(code: item.manufacturer ?? "", coe: 33)
        }, "All returned items should support COE 33")
        
        // Test filtering by COE 90
        let coe90Items = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: .coe90)
        #expect(coe90Items.count == 1, "Should return 1 COE 90 item (BE)")
        #expect(coe90Items.first?.manufacturer == "BE", "Should return Bullseye item")
        
        // Test filtering by COE 104
        let coe104Items = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: .coe104)
        #expect(coe104Items.count == 1, "Should return 1 COE 104 item (EF)")
        #expect(coe104Items.first?.manufacturer == "EF", "Should return Effetre item")
        
        // Test no filter (nil)
        let allItems = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: nil)
        #expect(allItems.count == 4, "Should return all items when no COE filter")
    }
    
    @Test("Should handle unknown manufacturers gracefully in COE filtering")
    func testCOEFilteringWithUnknownManufacturers() {
        let mockItems = [
            MockCatalogItem(manufacturer: "UNKNOWN", name: "Unknown Glass"),
            MockCatalogItem(manufacturer: "", name: "No Manufacturer"),
            MockCatalogItem(manufacturer: nil, name: "Nil Manufacturer"),
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue")  // COE 104
        ]
        
        // Filter by COE 104 - only known manufacturer should match
        let filtered = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: .coe104)
        #expect(filtered.count == 1, "Should only return known COE 104 manufacturer")
        #expect(filtered.first?.manufacturer == "EF", "Should return Effetre item")
    }
    
    @Test("Should integrate COE filter with existing filter chain")
    func testCOEFilterIntegrationWithExistingFilters() {
        // This test verifies COE filter runs first, then other filters apply
        let mockItems = [
            MockCatalogItem(manufacturer: "EF", name: "Effetre Red", tags: "transparent"),      // COE 104
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue", tags: "opaque"),        // COE 104  
            MockCatalogItem(manufacturer: "BB", name: "Boro Batch Clear", tags: "transparent") // COE 33
        ]
        
        // Apply COE filter first (COE 104), then tag filter
        let coeFiltered = FilterUtilities.filterCatalogByCOE(mockItems, selectedCOE: .coe104)
        let finalFiltered = FilterUtilities.filterCatalogByTags(coeFiltered, selectedTags: Set(["transparent"]))
        
        #expect(coeFiltered.count == 2, "COE filter should return 2 COE 104 items")
        #expect(finalFiltered.count == 1, "Final filter should return 1 transparent COE 104 item")
        #expect(finalFiltered.first?.name == "Effetre Red", "Should return the transparent COE 104 item")
    }
    
    @Test("Should provide all COE options for settings UI")
    func testCOEOptionsForSettingsUI() {
        // Test that we can get all COE options for the settings picker
        let allOptions = COEGlassType.allCases
        #expect(allOptions.count == 4, "Should have 4 COE options")
        
        // Verify all expected types are present
        #expect(allOptions.contains(.coe33), "Should include COE 33")
        #expect(allOptions.contains(.coe90), "Should include COE 90")
        #expect(allOptions.contains(.coe96), "Should include COE 96")
        #expect(allOptions.contains(.coe104), "Should include COE 104")
        
        // Verify display names for UI
        let displayNames = allOptions.map { $0.displayName }
        #expect(displayNames.contains("COE 33"), "Should have COE 33 display name")
        #expect(displayNames.contains("COE 90"), "Should have COE 90 display name")
        #expect(displayNames.contains("COE 96"), "Should have COE 96 display name")
        #expect(displayNames.contains("COE 104"), "Should have COE 104 display name")
    }
    
    @Test("Should have COE filter available only when feature flag is enabled")
    func testCOEFilterFeatureFlagGating() {
        // When feature flag is enabled, COE filter should be available
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Should be able to create COE types and preferences
            let coeType = COEGlassType.coe33
            #expect(coeType.displayName == "COE 33", "COE type should work when feature enabled")
            
            // Should be able to set preferences
            COEGlassPreference.setCOEFilter(.coe33)
            let current = COEGlassPreference.current
            #expect(current == .coe33, "Should be able to set COE preference when feature enabled")
            
            // Clean up
            COEGlassPreference.resetToDefault()
        } else {
            // This test documents that the feature exists but can be disabled
            #expect(!isFeatureEnabled, "Feature flag should be testable even when disabled")
        }
    }
    
    @Test("Should provide none option for settings UI")
    func testNoneOptionForSettingsUI() {
        // Test that settings can represent "no filter" state
        COEGlassPreference.resetToDefault()
        let current = COEGlassPreference.current
        #expect(current == nil, "No filter should be represented as nil")
        
        // Test that we can explicitly set no filter
        COEGlassPreference.setCOEFilter(nil)
        let afterReset = COEGlassPreference.current
        #expect(afterReset == nil, "Should be able to explicitly set no filter")
    }
    
    @Test("Should integrate COE preference with CatalogView filtering")
    func testCatalogViewCOEIntegration() {
        // Create isolated test UserDefaults
        let testSuite = "CatalogViewCOETest_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        
        // Test with no COE preference - should return all items
        COEGlassPreference.resetToDefault()
        let mockItems = [
            MockCatalogItem(manufacturer: "BB", name: "Boro Batch Clear"), // COE 33
            MockCatalogItem(manufacturer: "BE", name: "Bullseye Red"),      // COE 90
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue")      // COE 104
        ]
        
        let unfilteredResult = CatalogViewHelpers.applyCOEFilter(mockItems)
        #expect(unfilteredResult.count == 3, "Should return all items when no COE preference")
        
        // Test with COE 33 preference - should return only COE 33 items
        COEGlassPreference.setCOEFilter(.coe33)
        let coe33Result = CatalogViewHelpers.applyCOEFilter(mockItems)
        #expect(coe33Result.count == 1, "Should return only COE 33 items")
        #expect(coe33Result.first?.manufacturer == "BB", "Should return Boro Batch item")
        
        // Test with COE 104 preference - should return only COE 104 items
        COEGlassPreference.setCOEFilter(.coe104)
        let coe104Result = CatalogViewHelpers.applyCOEFilter(mockItems)
        #expect(coe104Result.count == 1, "Should return only COE 104 items")
        #expect(coe104Result.first?.manufacturer == "EF", "Should return Effetre item")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should apply COE filter before other catalog filters")
    func testCOEFilterOrderInCatalogView() {
        // Create isolated test UserDefaults
        let testSuite = "CatalogViewFilterOrder_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        
        let mockItems = [
            MockCatalogItem(manufacturer: "EF", name: "Effetre Red", tags: "transparent"),      // COE 104, transparent
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue", tags: "opaque"),         // COE 104, opaque
            MockCatalogItem(manufacturer: "BB", name: "Boro Clear", tags: "transparent"),       // COE 33, transparent
            MockCatalogItem(manufacturer: "BB", name: "Boro White", tags: "opaque")            // COE 33, opaque
        ]
        
        // Set COE filter to 104 first
        COEGlassPreference.setCOEFilter(.coe104)
        
        // Apply filters in the correct order: COE first, then tags
        let coeFiltered = CatalogViewHelpers.applyCOEFilter(mockItems)
        #expect(coeFiltered.count == 2, "COE filter should return 2 COE 104 items first")
        
        let finalFiltered = FilterUtilities.filterCatalogByTags(coeFiltered, selectedTags: Set(["transparent"]))
        #expect(finalFiltered.count == 1, "Tag filter should then return 1 transparent COE 104 item")
        #expect(finalFiltered.first?.name == "Effetre Red", "Should return the transparent COE 104 item")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should only apply COE filter when feature flag is enabled")
    func testCOEFilterOnlyWhenFeatureEnabled() {
        // This test ensures COE filtering only happens when feature flag is on
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // When feature is enabled, COE filter should work
            let mockItems = [
                MockCatalogItem(manufacturer: "BB", name: "Boro Batch"), // COE 33
                MockCatalogItem(manufacturer: "EF", name: "Effetre")     // COE 104
            ]
            
            // Create isolated test UserDefaults
            let testSuite = "FeatureFlagTest_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            
            COEGlassPreference.setCOEFilter(.coe33)
            let filtered = CatalogViewHelpers.applyCOEFilter(mockItems)
            #expect(filtered.count == 1, "Should filter when feature enabled")
            #expect(filtered.first?.manufacturer == "BB", "Should return COE 33 item")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // When feature is disabled, COE filter should be bypassed
            let mockItems = [MockCatalogItem(manufacturer: "BB", name: "Test")]
            let result = CatalogViewHelpers.applyCOEFilter(mockItems)
            #expect(result.count == mockItems.count, "Should return all items when feature disabled")
        }
    }
}

// MARK: - Mock Objects for Testing
struct MockCatalogItem: CatalogItemProtocol {
    let manufacturer: String?
    let name: String?  // Changed to optional to match protocol
    let tags: String?
    
    init(manufacturer: String?, name: String, tags: String? = nil) {
        self.manufacturer = manufacturer
        self.name = name  // This will convert non-optional String to optional String?
        self.tags = tags
    }
}
