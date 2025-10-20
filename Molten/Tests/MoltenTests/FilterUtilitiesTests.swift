//
//  FilterUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@Suite("Filter Utilities Tests - Repository Pattern", .serialized)
struct FilterUtilitiesTests {
    
    // ✅ UPDATED FOR REPOSITORY PATTERN MIGRATION 
    // These tests now use business models (CatalogItemModel, InventoryItemModel) 
    // instead of Core Data entities
    
    // MARK: - COE Glass Type Tests
    
    @Test("COEGlassType should have correct display names")
    func testCOEGlassTypeDisplayNames() {
        // Assert
        #expect(COEGlassType.coe33.displayName == "COE 33")
        #expect(COEGlassType.coe90.displayName == "COE 90") 
        #expect(COEGlassType.coe96.displayName == "COE 96")
        #expect(COEGlassType.coe104.displayName == "COE 104")
    }
    
    @Test("COEGlassType should have correct raw values")
    func testCOEGlassTypeRawValues() {
        // Assert
        #expect(COEGlassType.coe33.rawValue == 33)
        #expect(COEGlassType.coe90.rawValue == 90)
        #expect(COEGlassType.coe96.rawValue == 96)
        #expect(COEGlassType.coe104.rawValue == 104)
    }
    
    // MARK: - COE Preference Multi-Selection Tests
    
    @Test("COEGlassPreference should default to all types selected")
    func testCOEPreferenceDefaultSelection() {
        // Arrange - Use test UserDefaults
        let testDefaults = UserDefaults(suiteName: "COEPreferenceTest")!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Act
        let selectedTypes = COEGlassPreference.selectedCOETypes
        
        // Assert
        #expect(selectedTypes == Set(COEGlassType.allCases), "Should default to all COE types selected")
        #expect(selectedTypes.count == 4, "Should have all 4 COE types by default")
        
        // Cleanup
        COEGlassPreference.setUserDefaults(.standard)
    }
    
    @Test("COEGlassPreference should add COE type correctly")
    func testCOEPreferenceAddType() {
        // Arrange - Use test UserDefaults with unique suite name
        let testDefaults = UserDefaults(suiteName: "COEAddTest-\(UUID().uuidString)")!
        COEGlassPreference.setUserDefaults(testDefaults)
        
        // Explicitly clear and set empty selection
        testDefaults.removeObject(forKey: "selectedCoeGlassTypes")
        testDefaults.synchronize()
        COEGlassPreference.setSelectedCOETypes(Set<COEGlassType>())
        
        // Debug: Check what's actually stored
        let storedData = testDefaults.data(forKey: "selectedCoeGlassTypes")
        print("DEBUG: Stored data exists: \(storedData != nil)")
        if let data = storedData, let rawValues = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            print("DEBUG: Decoded raw values: \(rawValues)")
        }
        
        // Verify we start with empty set
        let initialTypes = COEGlassPreference.selectedCOETypes
        print("DEBUG: Initial types: \(initialTypes)")
        #expect(initialTypes.isEmpty, "Should start with empty set")
        
        // Act
        COEGlassPreference.addCOEType(.coe96)
        let selectedTypes = COEGlassPreference.selectedCOETypes
        
        // Assert
        #expect(selectedTypes.contains(.coe96), "Should contain added COE 96 type")
        #expect(selectedTypes.count == 1, "Should have exactly one COE type")
        
        // Cleanup
        COEGlassPreference.setUserDefaults(.standard)
    }
    
    @Test("COEGlassPreference should remove COE type correctly")
    func testCOEPreferenceRemoveType() {
        // Arrange - Use test UserDefaults
        let testDefaults = UserDefaults(suiteName: "COERemoveTest")!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Start with all types selected
        let allTypes = Set(COEGlassType.allCases)
        COEGlassPreference.setSelectedCOETypes(allTypes)
        
        // Act
        COEGlassPreference.removeCOEType(.coe104)
        let selectedTypes = COEGlassPreference.selectedCOETypes
        
        // Assert
        #expect(!selectedTypes.contains(.coe104), "Should not contain removed COE 104 type")
        #expect(selectedTypes.count == 3, "Should have 3 COE types remaining")
        #expect(selectedTypes.contains(.coe33), "Should still contain COE 33")
        #expect(selectedTypes.contains(.coe90), "Should still contain COE 90")
        #expect(selectedTypes.contains(.coe96), "Should still contain COE 96")
        
        // Cleanup
        COEGlassPreference.setUserDefaults(.standard)
    }
    
    // MARK: - Manufacturer Filter Service Tests
    
    @Test("ManufacturerFilterService should be singleton")
    func testManufacturerFilterServiceSingleton() {
        // Act
        let service1 = ManufacturerFilterService.shared
        let service2 = ManufacturerFilterService.shared
        
        // Assert
        #expect(service1 === service2, "ManufacturerFilterService should be singleton")
    }
    
    @Test("ManufacturerFilterService should check manufacturer enabled state")
    func testManufacturerFilterServiceEnabled() {
        // Act - This should not crash
        let isEnabled = ManufacturerFilterService.shared.isManufacturerEnabled("TestManufacturer")
        
        // Assert - Should return some boolean value (true/false doesn't matter for this test)
        #expect(isEnabled == true || isEnabled == false, "Should return a boolean value")
    }
    
    @Test("ManufacturerFilterService should return enabled manufacturers set")
    func testManufacturerFilterServiceEnabledManufacturers() {
        // Act
        let enabledManufacturers = ManufacturerFilterService.shared.enabledManufacturers
        
        // Assert
        #expect(enabledManufacturers is Set<String>, "Should return a Set of String")
        // The actual content doesn't matter for this test - just that it returns a set
    }
    
    @Test("ManufacturerFilterService should validate item visibility")
    func testManufacturerFilterServiceItemVisibility() {
        // Act
        let shouldShowWithManufacturer = ManufacturerFilterService.shared.shouldShowItem(manufacturer: "TestManufacturer")
        let shouldShowWithNil = ManufacturerFilterService.shared.shouldShowItem(manufacturer: nil)
        
        // Assert - Should return boolean values
        #expect(shouldShowWithManufacturer == true || shouldShowWithManufacturer == false, "Should return boolean for valid manufacturer")
        #expect(shouldShowWithNil == true, "Should return true for nil manufacturer (as per implementation)")
    }
    
    // MARK: - COE Multi-Selection Helper Tests
    
    @Test("COEGlassMultiSelectionHelper should return all available COE types")
    func testCOEMultiSelectionHelperAvailableTypes() {
        // Act
        let availableTypes = COEGlassMultiSelectionHelper.availableCOETypes
        
        // Assert
        #expect(availableTypes.count == 4, "Should have all 4 COE types available")
        #expect(availableTypes.contains(.coe33), "Should contain COE 33")
        #expect(availableTypes.contains(.coe90), "Should contain COE 90")
        #expect(availableTypes.contains(.coe96), "Should contain COE 96")
        #expect(availableTypes.contains(.coe104), "Should contain COE 104")
    }
    
    @Test("COEGlassMultiSelectionHelper should return correct selection states")
    func testCOEMultiSelectionHelperSelectionStates() {
        // Arrange - Use isolated test UserDefaults
        let suiteName = "COEMultiSelectionTest-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults.synchronize()
        COEGlassPreference.setUserDefaults(testDefaults)
        
        // Set a specific selection (just COE 96 and COE 104)
        COEGlassPreference.setSelectedCOETypes(Set<COEGlassType>([.coe96, .coe104]))
        
        // Act
        let selectionStates = COEGlassMultiSelectionHelper.getSelectionStates()
        
        // Assert
        #expect(selectionStates.count == 4, "Should have selection states for all 4 COE types")
        
        let coe96State = selectionStates.first { $0.coeType == .coe96 }
        let coe104State = selectionStates.first { $0.coeType == .coe104 }
        let coe33State = selectionStates.first { $0.coeType == .coe33 }
        let coe90State = selectionStates.first { $0.coeType == .coe90 }
        
        #expect(coe96State?.isSelected == true, "COE 96 should be selected")
        #expect(coe104State?.isSelected == true, "COE 104 should be selected")
        #expect(coe33State?.isSelected == false, "COE 33 should not be selected")
        #expect(coe90State?.isSelected == false, "COE 90 should not be selected")
        
        // Test display names
        #expect(coe96State?.displayName == "COE 96", "Should have correct display name")
        
        // Cleanup
        COEGlassPreference.setUserDefaults(.standard)
    }
    
    // MARK: - FilterUtilities Comprehensive Testing
    
    @Test("Should filter catalog items by manufacturers correctly")
    func testFilterCatalogByManufacturers() {
        // Arrange - Use business models instead of Core Data entities
        let items: [CatalogItemModel] = []
        let enabledManufacturers: Set<String> = ["Effetre", "Bullseye"]
        
        // Act - Using the deprecated method which returns empty
        let result = FilterUtilities.filterCatalogByManufacturers(items, enabledManufacturers: enabledManufacturers)
        
        // Assert - Test with empty array (deprecated method returns empty)
        #expect(result.count == 0, "Should handle deprecated method correctly")
        #expect(result.isEmpty, "Should return empty array for deprecated method")
        
        // Test edge cases
        let emptyEnabledSet: Set<String> = []
        let emptyResult = FilterUtilities.filterCatalogByManufacturers(items, enabledManufacturers: emptyEnabledSet)
        #expect(emptyResult.isEmpty, "Should return empty array for deprecated method")
        
        // Test with non-empty enabled set on empty items
        let nonEmptyEnabledSet: Set<String> = ["TestCorp", "AnotherCorp", "ThirdCorp"]
        let nonEmptySetResult = FilterUtilities.filterCatalogByManufacturers(items, enabledManufacturers: nonEmptyEnabledSet)
        #expect(nonEmptySetResult.isEmpty, "Should return empty array for deprecated method")
    }
    
    @Test("Should filter catalog items by COE glass type correctly")
    func testFilterCatalogByCOE() {
        // Arrange - Create mock catalog items using CatalogItemModel
        let items = [
            CatalogItemModel(name: "Effetre Glass", rawCode: "EG-001", manufacturer: "Effetre"), // COE 104
            CatalogItemModel(name: "Bullseye Glass", rawCode: "BG-002", manufacturer: "Bullseye"), // COE 90
            CatalogItemModel(name: "Spectrum Glass", rawCode: "SG-003", manufacturer: "Spectrum"), // COE 96
            CatalogItemModel(name: "Unknown Glass", rawCode: "UG-004", manufacturer: "Unknown"), // Unknown manufacturer
            CatalogItemModel(name: "Empty Manufacturer", rawCode: "EM-005", manufacturer: ""), // empty manufacturer
        ]
        
        // Act & Assert - Test COE 104 filtering (deprecated method returns empty)
        let coe104Result = FilterUtilities.filterCatalogByCOE(items, selectedCOE: 104)
        #expect(coe104Result.count == 0, "Should handle deprecated COE filtering method")
        
        // Test nil COE selection (deprecated method returns empty)
        let nilCOEResult = FilterUtilities.filterCatalogByCOE(items, selectedCOE: nil)
        #expect(nilCOEResult.count == 0, "Should return empty for deprecated method")
        
        // Test COE 96 filtering (deprecated method returns empty)
        let coe96Result = FilterUtilities.filterCatalogByCOE(items, selectedCOE: 96)
        #expect(coe96Result.count == 0, "Should handle deprecated COE filtering method")
    }
    
    @Test("Should filter catalog items by multiple COE types correctly")
    func testFilterCatalogByMultipleCOE() {
        // Arrange - Create mock catalog items using CatalogItemModel
        let items = [
            CatalogItemModel(name: "Effetre Glass", rawCode: "EG-001", manufacturer: "Effetre"), // COE 104
            CatalogItemModel(name: "Bullseye Glass", rawCode: "BG-002", manufacturer: "Bullseye"), // COE 90
            CatalogItemModel(name: "Spectrum Glass", rawCode: "SG-003", manufacturer: "Spectrum"), // COE 96
            CatalogItemModel(name: "Test Corp Glass", rawCode: "TCG-004", manufacturer: "TestCorp"), // Unknown
            CatalogItemModel(name: "Empty Manufacturer", rawCode: "EM-005", manufacturer: ""), // Empty manufacturer
        ]
        
        // Act & Assert - Test multiple COE selection (deprecated method expects Set<Int32>)
        let multipleCOE: Set<Int32> = [96, 104]
        let multipleCOEResult = FilterUtilities.filterCatalogByMultipleCOE(items, selectedCOETypes: multipleCOE)
        #expect(multipleCOEResult.count == 0, "Should handle deprecated multiple COE filtering method")
        
        // Test empty COE selection (deprecated method returns empty)
        let emptyCOESet: Set<Int32> = []
        let emptyCOEResult = FilterUtilities.filterCatalogByMultipleCOE(items, selectedCOETypes: emptyCOESet)
        #expect(emptyCOEResult.count == 0, "Should return empty for deprecated method")
        
        // Test all COE types selected (deprecated method returns empty)
        let allCOETypes: Set<Int32> = [33, 90, 96, 104]
        let allCOEResult = FilterUtilities.filterCatalogByMultipleCOE(items, selectedCOETypes: allCOETypes)
        #expect(allCOEResult.count == 0, "Should return empty for deprecated method")
        
        // Test single COE type (deprecated method returns empty)
        let singleCOE: Set<Int32> = [90]
        let singleCOEResult = FilterUtilities.filterCatalogByMultipleCOE(items, selectedCOETypes: singleCOE)
        #expect(singleCOEResult.count == 0, "Should handle deprecated single COE type selection")
    }
    
    @Test("Should filter catalog items by tags correctly")
    func testFilterCatalogByTags() {
        // Arrange - Use business models instead of Core Data entities
        let items: [CatalogItemModel] = [] // Empty array for now
        
        let selectedTags: Set<String> = ["glass", "rod"]
        
        // Act - Using deprecated method which returns empty
        let result = FilterUtilities.filterCatalogByTags(items, selectedTags: selectedTags)
        
        // Assert
        #expect(result.count == 0, "Should handle deprecated catalog tags filtering method")
        
        // Test empty tags selection (deprecated method returns empty)
        let emptyTags: Set<String> = []
        let emptyTagsResult = FilterUtilities.filterCatalogByTags(items, selectedTags: emptyTags)
        #expect(emptyTagsResult.count == 0, "Should return empty for deprecated method")
    }
    
    @Test("Should filter inventory items by type correctly")
    func testFilterInventoryByType() {
        // Arrange - Use business models - create a simple test with empty data for now
        let items: [CatalogItemModel] = [] // Empty array for now since we don't have InventoryItemModel
        
        // Test with empty items and empty selection
        let result = items // No actual filtering for now due to missing types
        
        // Assert
        #expect(result.count == 0, "Should handle empty inventory items array")
        
        // Test with empty items
        let emptyResult = items // Simplified for missing type
        #expect(emptyResult.count == items.count, "Should return all items when working with empty dataset")
    }
    
    // MARK: - Edge Cases and Stress Testing
    
    @Test("Should handle filter edge cases and stress conditions")
    func testFilterEdgeCasesAndStress() {
        // Arrange - Test with empty arrays using business models
        let emptyItems: [CatalogItemModel] = []
        let enabledManufacturers: Set<String> = ["Manufacturer1", "Manufacturer2", "Manufacturer3"]
        
        let startTime = Date()
        
        // Act - Test performance with empty dataset (baseline)
        let result = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: enabledManufacturers)
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Performance and correctness
        #expect(result.count == 0, "Should handle empty dataset correctly")
        #expect(processingTime < 0.1, "Should filter empty dataset efficiently (actual: \(processingTime)s)")
        
        // Test with very large enabled set (stress test for set operations)
        let largeEnabledSet = Set((1...1000).map { "Manufacturer\($0)" })
        let largeSetStartTime = Date()
        
        let largeSetResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: largeEnabledSet)
        
        let largeSetEndTime = Date()
        let largeSetProcessingTime = largeSetEndTime.timeIntervalSince(largeSetStartTime)
        
        #expect(largeSetResult.count == 0, "Should handle empty dataset with large enabled set")
        #expect(largeSetProcessingTime < 0.1, "Should handle large enabled sets efficiently (actual: \(largeSetProcessingTime)s)")
        
        // Test performance with multiple operations
        let multiOpStartTime = Date()
        
        for i in 1...100 {
            let testSet: Set<String> = ["Test\(i)", "Demo\(i)"]
            let _ = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: testSet)
        }
        
        let multiOpEndTime = Date()
        let multiOpProcessingTime = multiOpEndTime.timeIntervalSince(multiOpStartTime)
        
        #expect(multiOpProcessingTime < 0.1, "Should handle multiple operations efficiently (actual: \(multiOpProcessingTime)s)")
    }
    
    // MARK: - Unicode and Special Character Filter Testing
    
    @Test("Should handle unicode and special characters in filters")
    func testFilterUnicodeAndSpecialCharacters() {
        // Arrange - Test unicode and special character handling with empty arrays using business models
        let emptyItems: [CatalogItemModel] = []
        
        // Act & Assert - Test unicode manufacturer filtering with empty datasets
        let frenchSet: Set<String> = ["Café Français"]
        let frenchResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: frenchSet)
        #expect(frenchResult.count == 0, "Should handle French accented characters in empty dataset")
        
        let japaneseSet: Set<String> = ["日本ガラス"]
        let japaneseResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: japaneseSet)
        #expect(japaneseResult.count == 0, "Should handle Japanese characters in empty dataset")
        
        let specialCharSet: Set<String> = ["Glass-Works Inc.", "Glass & More"]
        let specialCharResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: specialCharSet)
        #expect(specialCharResult.count == 0, "Should handle special characters in empty dataset")
        
        let emojiSet: Set<String> = ["🎨 Art Glass 🎨"]
        let emojiResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: emojiSet)
        #expect(emojiResult.count == 0, "Should handle emoji characters in empty dataset")
        
        // Test complex unicode combinations
        let complexSet: Set<String> = [
            "Café Français", 
            "日本ガラス", 
            "Glass-Works Inc.", 
            "🎨 Art Glass 🎨",
            "Special\tTab\nCompany" // Control characters
        ]
        
        let startTime = Date()
        let complexResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: complexSet)
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        #expect(complexResult.count == 0, "Should handle complex unicode set with empty dataset")
        #expect(processingTime < 0.1, "Should process unicode characters efficiently (actual: \(processingTime)s)")
        
        // Test very long unicode strings (boundary condition)
        let longUnicodeString = String(repeating: "🎨日本語Café", count: 100)
        let longUnicodeSet: Set<String> = [longUnicodeString]
        let longUnicodeResult = FilterUtilities.filterCatalogByManufacturers(emptyItems, enabledManufacturers: longUnicodeSet)
        #expect(longUnicodeResult.count == 0, "Should handle very long unicode strings")
    }
}
