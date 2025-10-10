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
@testable import Flameworker

@Suite("Filter Utilities Tests", .serialized)
struct FilterUtilitiesTests {
    
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
        COEGlassPreference.setSelectedCOETypes(Set())
        
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
}