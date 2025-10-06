//
//  COEGlassMultiSelectionTests.swift
//  FlameworkerTests
//
//  Tests for COE glass multi-selection functionality
//  Created by TDD on 10/5/25.
//

import Testing
@testable import Flameworker

@Suite("COE Glass Multi-Selection Tests")
struct COEGlassMultiSelectionTests {
    
    @Test("Should default to all COE types selected")
    func testDefaultAllCOESelected() {
        // Create isolated test UserDefaults
        let testSuite = "MultiSelectDefault_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Should default to all COE types selected
        let defaultSelection = COEGlassPreference.selectedCOETypes
        #expect(defaultSelection.contains(.coe33), "Should default to COE 33 selected")
        #expect(defaultSelection.contains(.coe90), "Should default to COE 90 selected")
        #expect(defaultSelection.contains(.coe96), "Should default to COE 96 selected")  
        #expect(defaultSelection.contains(.coe104), "Should default to COE 104 selected")
        #expect(defaultSelection.count == 4, "Should have all 4 COE types selected by default")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should support adding and removing COE types from selection")
    func testCOESelectionAddRemove() {
        // Create isolated test UserDefaults
        let testSuite = "MultiSelectAddRemove_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Start with all selected
        var selection = COEGlassPreference.selectedCOETypes
        #expect(selection.count == 4, "Should start with all selected")
        
        // Remove COE 33
        COEGlassPreference.removeCOEType(.coe33)
        selection = COEGlassPreference.selectedCOETypes
        #expect(!selection.contains(.coe33), "Should remove COE 33")
        #expect(selection.count == 3, "Should have 3 types after removal")
        
        // Add COE 33 back
        COEGlassPreference.addCOEType(.coe33)
        selection = COEGlassPreference.selectedCOETypes
        #expect(selection.contains(.coe33), "Should add COE 33 back")
        #expect(selection.count == 4, "Should have all 4 types again")
        
        // Remove multiple types
        COEGlassPreference.removeCOEType(.coe90)
        COEGlassPreference.removeCOEType(.coe96)
        selection = COEGlassPreference.selectedCOETypes
        #expect(selection.count == 2, "Should have 2 types after removing 2")
        #expect(selection.contains(.coe33), "Should still have COE 33")
        #expect(selection.contains(.coe104), "Should still have COE 104")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should filter catalog by multiple selected COE types")
    func testMultiCOEFiltering() {
        let mockItems = [
            MockCatalogItem(manufacturer: "BB", name: "Boro Batch Clear"), // COE 33
            MockCatalogItem(manufacturer: "BE", name: "Bullseye Red"),      // COE 90
            MockCatalogItem(manufacturer: "EF", name: "Effetre Blue"),     // COE 104
            MockCatalogItem(manufacturer: "NS", name: "Northstar Green")   // COE 33
        ]
        
        // Test filtering with COE 33 and 104 selected
        let selectedTypes = Set([COEGlassType.coe33, COEGlassType.coe104])
        let filtered = FilterUtilities.filterCatalogByMultipleCOE(mockItems, selectedCOETypes: selectedTypes)
        
        #expect(filtered.count == 3, "Should return COE 33 and 104 items (BB, EF, NS)")
        
        let manufacturers = Set(filtered.compactMap { $0.manufacturer })
        #expect(manufacturers.contains("BB"), "Should include Boro Batch (COE 33)")
        #expect(manufacturers.contains("EF"), "Should include Effetre (COE 104)")
        #expect(manufacturers.contains("NS"), "Should include Northstar (COE 33)")
        #expect(!manufacturers.contains("BE"), "Should not include Bullseye (COE 90)")
        
        // Test filtering with only COE 90 selected
        let coe90Only = Set([COEGlassType.coe90])
        let coe90Filtered = FilterUtilities.filterCatalogByMultipleCOE(mockItems, selectedCOETypes: coe90Only)
        
        #expect(coe90Filtered.count == 1, "Should return only COE 90 items")
        #expect(coe90Filtered.first?.manufacturer == "BE", "Should return Bullseye item")
        
        // Test with all COE types selected (should return all items)
        let allTypes = Set(COEGlassType.allCases)
        let allFiltered = FilterUtilities.filterCatalogByMultipleCOE(mockItems, selectedCOETypes: allTypes)
        #expect(allFiltered.count == 4, "Should return all items when all COE types selected")
    }
    
    @Test("Should provide multi-selection options for Settings UI")
    func testMultiSelectionSettingsUI() {
        // Create isolated test UserDefaults
        let testSuite = "MultiSelectUI_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Should provide all COE options for multi-selection UI
        let allOptions = COEGlassMultiSelectionHelper.availableCOETypes
        #expect(allOptions.count == 4, "Should provide 4 COE options")
        
        // Should indicate which are currently selected (all by default)
        let selectionStates = COEGlassMultiSelectionHelper.getSelectionStates()
        #expect(selectionStates.count == 4, "Should have selection state for each option")
        #expect(selectionStates.allSatisfy { $0.isSelected }, "All should be selected by default")
        
        // Test toggling selection
        COEGlassMultiSelectionHelper.toggleCOEType(.coe33)
        let updatedStates = COEGlassMultiSelectionHelper.getSelectionStates()
        let coe33State = updatedStates.first { $0.coeType == .coe33 }
        #expect(coe33State?.isSelected == false, "COE 33 should be unselected after toggle")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
}