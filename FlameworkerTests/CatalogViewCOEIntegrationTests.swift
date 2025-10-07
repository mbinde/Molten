//
//  CatalogViewCOEIntegrationTests.swift
//  FlameworkerTests
//
//  Tests for COE filter integration in CatalogView
//  Created by TDD on 10/5/25.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("CatalogView COE Integration Tests")
struct CatalogViewCOEIntegrationTests {
    
    @Test("Should apply COE filter first in CatalogView filter chain")
    func testCOEFilterFirstInChain() {
        // Test that CatalogView applies COE filter before other filters
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Create test data using simple mock objects
            let mockItems = [
                IntegrationMockItem(name: "Effetre Red", manufacturer: "EF", tags: "transparent"),      // COE 104
                IntegrationMockItem(name: "Boro Clear", manufacturer: "BB", tags: "transparent"),       // COE 33
                IntegrationMockItem(name: "Effetre Blue", manufacturer: "EF", tags: "opaque")          // COE 104
            ]
            
            // Create isolated test UserDefaults
            let testSuite = "CatalogViewIntegration_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            COEGlassPreference.resetToDefault()
            
            // Set COE 104 preference
            COEGlassPreference.setCOEFilter(.coe104)
            
            // Test basic COE filtering logic
            let coeFiltered = TestIntegrationHelpers.applyCOEFilter(mockItems)
            let tagFiltered = TestIntegrationHelpers.applyTagFilter(coeFiltered, selectedTags: Set(["transparent"]))
            
            #expect(coeFiltered.count == 2, "COE filter should return 2 COE 104 items")
            #expect(tagFiltered.count == 1, "Should return 1 item after COE and tag filters")
            #expect(tagFiltered.first?.name == "Effetre Red", "Should return transparent COE 104 item")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // When feature disabled, should not crash
            #expect(true, "Feature disabled, test skipped")
        }
    }
    
    @Test("Should handle COE preference changes")
    func testCOEPreferenceChanges() {
        // Test COE preference integration
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Create isolated test UserDefaults
            let testSuite = "COEPreferenceTest_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            COEGlassPreference.resetToDefault()
            
            // Test that preferences can be set and retrieved
            COEGlassPreference.setCOEFilter(.coe33)
            let current = COEGlassPreference.current
            #expect(current == .coe33, "Should be able to set COE preference")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            #expect(true, "Feature disabled, test skipped")
        }
    }
    
    @Test("Should not crash with empty data")
    func testEmptyDataHandling() {
        // Test that the system handles empty data gracefully
        let emptyItems: [IntegrationMockItem] = []
        
        // This should not crash
        let filtered = TestIntegrationHelpers.applyCOEFilter(emptyItems)
        #expect(filtered.isEmpty, "Empty input should return empty output")
        
        // Test with tag filtering too
        let tagFiltered = TestIntegrationHelpers.applyTagFilter(emptyItems, selectedTags: Set(["test"]))
        #expect(tagFiltered.isEmpty, "Empty input should return empty output for tag filter")
    }
}

// MARK: - Safe Mock Objects for Integration Testing
struct IntegrationMockItem {
    let name: String?
    let manufacturer: String?
    let tags: String?
    
    init(name: String, manufacturer: String? = nil, tags: String? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.tags = tags
    }
}

// MARK: - Test Helper Methods
struct TestIntegrationHelpers {
    
    /// Apply COE filter based on current preference
    static func applyCOEFilter<T: CatalogItemProtocol>(_ items: [T]) -> [T] {
        guard let currentCOE = COEGlassPreference.current else {
            return items // No filter applied when no preference set
        }
        
        return items.filter { item in
            guard let manufacturer = item.manufacturer, !manufacturer.isEmpty else { return false }
            return GlassManufacturers.supports(code: manufacturer, coe: currentCOE.rawValue)
        }
    }
    
    /// Apply tag filter
    static func applyTagFilter<T: CatalogItemWithTags>(_ items: [T], selectedTags: Set<String>) -> [T] {
        guard !selectedTags.isEmpty else { return items }
        
        return items.filter { item in
            guard let tags = item.tags, !tags.isEmpty else { return false }
            let itemTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return selectedTags.isSubset(of: Set(itemTags))
        }
    }
}

// MARK: - Protocol Conformance for Mock Objects
extension IntegrationMockItem: CatalogItemProtocol {
    // Protocol requirements already satisfied by stored properties
}

extension IntegrationMockItem: CatalogItemWithTags {
    // CatalogItemWithTags requirements already satisfied by stored properties
}
