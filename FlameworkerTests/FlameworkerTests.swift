//
//  FlameworkerTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/2/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
@testable import Flameworker

@Suite("WeightUnit Tests")
struct WeightUnitTests {
    
    @Test("WeightUnit has correct display names")
    func testDisplayNames() {
        #expect(WeightUnit.pounds.displayName == "Pounds")
        #expect(WeightUnit.kilograms.displayName == "Kilograms")
    }
    
    @Test("WeightUnit has correct symbols")
    func testSymbols() {
        #expect(WeightUnit.pounds.symbol == "lb")
        #expect(WeightUnit.kilograms.symbol == "kg")
    }
    
    @Test("WeightUnit conversion from pounds to kilograms")
    func testPoundsToKilogramsConversion() {
        let result = WeightUnit.pounds.convert(10.0, to: .kilograms)
        #expect(abs(result - 4.53592) < 0.0001, "10 pounds should convert to ~4.53592 kg")
    }
    
    @Test("WeightUnit conversion from kilograms to pounds")
    func testKilogramsToPoundsConversion() {
        let result = WeightUnit.kilograms.convert(5.0, to: .pounds)
        #expect(abs(result - 11.0231) < 0.001, "5 kg should convert to ~11.0231 pounds")
    }
    
    @Test("WeightUnit same unit conversion returns original value")
    func testSameUnitConversion() {
        #expect(WeightUnit.pounds.convert(10.0, to: .pounds) == 10.0)
        #expect(WeightUnit.kilograms.convert(5.0, to: .kilograms) == 5.0)
    }
    
    @Test("WeightUnit has correct system image")
    func testSystemImage() {
        #expect(WeightUnit.pounds.systemImage == "scalemass")
        #expect(WeightUnit.kilograms.systemImage == "scalemass")
    }
}

@Suite("InventoryUnits Tests")
struct InventoryUnitsTests {
    
    @Test("InventoryUnits has correct display names")
    func testDisplayNames() {
        #expect(InventoryUnits.shorts.displayName == "Shorts")
        #expect(InventoryUnits.rods.displayName == "Rods")
        #expect(InventoryUnits.ounces.displayName == "oz")
        #expect(InventoryUnits.pounds.displayName == "lb")
        #expect(InventoryUnits.grams.displayName == "g")
        #expect(InventoryUnits.kilograms.displayName == "kg")
    }
    
    @Test("InventoryUnits initializes from raw value correctly")
    func testInitFromRawValue() {
        #expect(InventoryUnits(from: 0) == .shorts)
        #expect(InventoryUnits(from: 1) == .rods)
        #expect(InventoryUnits(from: 2) == .ounces)
        #expect(InventoryUnits(from: 3) == .pounds)
        #expect(InventoryUnits(from: 4) == .grams)
        #expect(InventoryUnits(from: 5) == .kilograms)
    }
    
    @Test("InventoryUnits falls back to shorts for invalid raw values")
    func testInitFromInvalidRawValue() {
        #expect(InventoryUnits(from: -1) == .shorts)
        #expect(InventoryUnits(from: 999) == .shorts)
    }
    
    @Test("InventoryUnits has correct ID values")
    func testIdValues() {
        #expect(InventoryUnits.shorts.id == 0)
        #expect(InventoryUnits.rods.id == 1)
        #expect(InventoryUnits.ounces.id == 2)
        #expect(InventoryUnits.pounds.id == 3)
        #expect(InventoryUnits.grams.id == 4)
        #expect(InventoryUnits.kilograms.id == 5)
    }
}

@Suite("InventoryItemType Tests")
struct InventoryItemTypeTests {
    
    @Test("InventoryItemType has correct display names")
    func testDisplayNames() {
        #expect(InventoryItemType.inventory.displayName == "Inventory")
        #expect(InventoryItemType.buy.displayName == "Buy")
        #expect(InventoryItemType.sell.displayName == "Sell")
    }
    
    @Test("InventoryItemType has correct system image names")
    func testSystemImageNames() {
        #expect(InventoryItemType.inventory.systemImageName == "archivebox.fill")
        #expect(InventoryItemType.buy.systemImageName == "cart.badge.plus")
        #expect(InventoryItemType.sell.systemImageName == "dollarsign.circle.fill")
    }
    
    @Test("InventoryItemType initializes from raw value correctly")
    func testInitFromRawValue() {
        #expect(InventoryItemType(from: 0) == .inventory)
        #expect(InventoryItemType(from: 1) == .buy)
        #expect(InventoryItemType(from: 2) == .sell)
    }
    
    @Test("InventoryItemType falls back to inventory for invalid raw values")
    func testInitFromInvalidRawValue() {
        #expect(InventoryItemType(from: -1) == .inventory)
        #expect(InventoryItemType(from: 999) == .inventory)
    }
    
    @Test("InventoryItemType has correct ID values")
    func testIdValues() {
        #expect(InventoryItemType.inventory.id == 0)
        #expect(InventoryItemType.buy.id == 1)
        #expect(InventoryItemType.sell.id == 2)
    }
}

@Suite("ImageHelpers Tests")
struct ImageHelpersTests {
    
    @Test("Sanitize item code replaces forward slashes")
    func testSanitizeForwardSlashes() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("ABC/123/XYZ")
        #expect(result == "ABC-123-XYZ")
    }
    
    @Test("Sanitize item code replaces backward slashes")
    func testSanitizeBackwardSlashes() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("ABC\\123\\XYZ")
        #expect(result == "ABC-123-XYZ")
    }
    
    @Test("Sanitize item code handles mixed slashes")
    func testSanitizeMixedSlashes() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("ABC/123\\XYZ")
        #expect(result == "ABC-123-XYZ")
    }
    
    @Test("Sanitize item code leaves normal characters unchanged")
    func testSanitizeNormalCharacters() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("ABC123XYZ")
        #expect(result == "ABC123XYZ")
    }
    
    @Test("Sanitize item code handles empty string")
    func testSanitizeEmptyString() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("")
        #expect(result == "")
    }
    
    @Test("Sanitize item code handles special characters except slashes")
    func testSanitizeSpecialCharacters() {
        let result = ImageHelpers.sanitizeItemCodeForFilename("ABC-123_XYZ.test")
        #expect(result == "ABC-123_XYZ.test")
    }
}

@Suite("UnitsDisplayHelper Tests")
struct UnitsDisplayHelperTests {
    
    @Test("Display names for inventory units")
    func testDisplayNames() {
        #expect(UnitsDisplayHelper.displayName(for: .ounces) == "oz")
        #expect(UnitsDisplayHelper.displayName(for: .pounds) == "lb")
        #expect(UnitsDisplayHelper.displayName(for: .grams) == "g")
        #expect(UnitsDisplayHelper.displayName(for: .kilograms) == "kg")
        #expect(UnitsDisplayHelper.displayName(for: .shorts) == "Shorts")
        #expect(UnitsDisplayHelper.displayName(for: .rods) == "Rods")
    }
    
    @Test("Convert ounces to user's preferred weight unit")
    func testConvertOuncesToPreferredUnit() {
        // Test with pounds preference
        let testSuiteName = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        let result = UnitsDisplayHelper.convertCount(32.0, from: .ounces)
        
        // 32oz = 2lb normalized, should stay as pounds
        #expect(result.unit == "lb", "Should use pounds when preference is set to pounds")
        #expect(abs(result.count - 2.0) < 0.01, "32 ounces should convert to 2 pounds")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Convert grams to user's preferred weight unit") 
    func testConvertGramsToPreferredUnit() {
        // Test with kilograms preference
        let testSuiteName = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        let result = UnitsDisplayHelper.convertCount(2000.0, from: .grams)
        
        // 2000g = 2kg normalized, should stay as kilograms
        #expect(result.unit == "kg", "Should use kilograms when preference is set to kilograms")
        #expect(abs(result.count - 2.0) < 0.01, "2000 grams should convert to 2 kg")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Conversion follows two-stage process")
    func testTwoStageConversionProcess() {
        // Test with a specific preference to make test predictable
        let testSuiteName = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Test the actual behavior: small units → large units → preferred system
        let gramsResult = UnitsDisplayHelper.convertCount(1000.0, from: .grams)
        let ouncesResult = UnitsDisplayHelper.convertCount(16.0, from: .ounces)
        
        // Both should be converted to pounds (our test preference)
        #expect(gramsResult.unit == "lb", "Should convert to pounds preference")
        #expect(ouncesResult.unit == "lb", "Should convert to pounds preference")
        
        // Verify the math:
        // 1000g = 1kg → 1/0.453592 ≈ 2.205 lb
        // 16oz = 1lb → 1.0 lb (no conversion needed)
        #expect(abs(gramsResult.count - 2.205) < 0.01, "1000g → 1kg → ~2.205 lb")
        #expect(abs(ouncesResult.count - 1.0) < 0.01, "16oz → 1lb → 1 lb")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Non-weight units remain unchanged")
    func testNonWeightUnitsUnchanged() {
        let shortsResult = UnitsDisplayHelper.convertCount(10.0, from: .shorts)
        #expect(shortsResult.count == 10.0)
        #expect(shortsResult.unit == "Shorts")
        
        let rodsResult = UnitsDisplayHelper.convertCount(5.0, from: .rods)
        #expect(rodsResult.count == 5.0)
        #expect(rodsResult.unit == "Rods")
    }
    
    @Test("Preferred weight unit returns correct inventory units")
    func testPreferredWeightUnit() {
        // Test with explicit preferences to avoid depending on global state
        
        // Test pounds preference
        let testSuiteName1 = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        let testUserDefaults1 = UserDefaults(suiteName: testSuiteName1)!
        testUserDefaults1.set("Pounds", forKey: WeightUnitPreference.storageKey)
        
        WeightUnitPreference.setUserDefaults(testUserDefaults1)
        let poundsResult = UnitsDisplayHelper.preferredWeightUnit()
        #expect(poundsResult == .pounds, "Should return pounds when preference is Pounds")
        
        // Clean up first test
        WeightUnitPreference.resetToStandard()
        testUserDefaults1.removeSuite(named: testSuiteName1)
        
        // Test kilograms preference  
        let testSuiteName2 = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        let testUserDefaults2 = UserDefaults(suiteName: testSuiteName2)!
        testUserDefaults2.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        
        WeightUnitPreference.setUserDefaults(testUserDefaults2)
        let kilogramsResult = UnitsDisplayHelper.preferredWeightUnit()
        #expect(kilogramsResult == .kilograms, "Should return kilograms when preference is Kilograms")
        
        // Clean up second test
        WeightUnitPreference.resetToStandard()
        testUserDefaults2.removeSuite(named: testSuiteName2)
    }
}

@Suite("WeightUnitPreference Tests")
struct WeightUnitPreferenceTests {
    
    @Test("Debug: Check what's happening with UserDefaults")
    func testDebugUserDefaults() {
        print("🔍 Starting debug test...")
        
        // Test 1: Check standard UserDefaults current state
        let standardCurrent = WeightUnitPreference.current
        print("🔍 Standard UserDefaults current: \(standardCurrent)")
        
        // Test 2: Create fresh test UserDefaults
        let testSuiteName = "DebugTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        print("🔍 Created test UserDefaults: \(testSuiteName)")
        
        // Test 3: Check test UserDefaults is clean
        let testValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
        print("🔍 Test UserDefaults value before injection: \(testValue ?? "nil")")
        
        // Test 4: Inject test UserDefaults
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        print("🔍 Injected test UserDefaults")
        
        // Test 5: Check current after injection
        let afterInjectionCurrent = WeightUnitPreference.current
        print("🔍 Current after injection: \(afterInjectionCurrent)")
        
        // Test 6: Set a value and check
        testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        let afterSetCurrent = WeightUnitPreference.current
        print("🔍 Current after setting Kilograms: \(afterSetCurrent)")
        
        // Test 7: Reset and check
        WeightUnitPreference.resetToStandard()
        let afterResetCurrent = WeightUnitPreference.current
        print("🔍 Current after reset: \(afterResetCurrent)")
        
        // Clean up
        testUserDefaults.removeSuite(named: testSuiteName)
        
        // Just pass the test - we're debugging
        #expect(true, "Debug test completed - check console output")
    }
    
    /// Helper to run a test with a clean, isolated UserDefaults instance
    private func withTestUserDefaults<T>(body: (UserDefaults) -> T) -> T {
        // Create a unique test suite name for this test run
        let testSuiteName = "WeightUnitPreferenceTests_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Set WeightUnitPreference to use our test UserDefaults
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Run the test
        let result = body(testUserDefaults)
        
        // Clean up: reset to standard UserDefaults
        WeightUnitPreference.resetToStandard()
        
        // Remove the test suite
        testUserDefaults.removeSuite(named: testSuiteName)
        
        return result
    }
    
    @Test("Current weight unit defaults to pounds when no preference set")
    func testDefaultToPounds() {
        withTestUserDefaults { testUserDefaults in
            // Verify no value is set (should be nil in fresh UserDefaults)
            let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
            #expect(storedValue == nil, "Fresh UserDefaults should have no value, but got: \(storedValue ?? "nil")")
            
            let current = WeightUnitPreference.current
            #expect(current == .pounds, "Should default to pounds when no preference is set, but got: \(current)")
        }
    }
    
    @Test("Current weight unit defaults to pounds when empty string preference")
    func testDefaultToPoundsWithEmptyString() {
        withTestUserDefaults { testUserDefaults in
            testUserDefaults.set("", forKey: WeightUnitPreference.storageKey)
            
            let current = WeightUnitPreference.current
            #expect(current == .pounds, "Should default to pounds when preference is empty string")
        }
    }
    
    @Test("Current weight unit returns pounds for 'Pounds' preference")
    func testPoundsPreference() {
        withTestUserDefaults { testUserDefaults in
            testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
            
            let current = WeightUnitPreference.current
            #expect(current == .pounds, "Should return pounds for 'Pounds' preference")
        }
    }
    
    @Test("Current weight unit returns kilograms for 'Kilograms' preference")
    func testKilogramsPreference() {
        withTestUserDefaults { testUserDefaults in
            testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
            
            // Verify the value was actually set
            let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
            #expect(storedValue == "Kilograms", "UserDefaults should store 'Kilograms', but got: \(storedValue ?? "nil")")
            
            let current = WeightUnitPreference.current
            #expect(current == .kilograms, "Should return kilograms for 'Kilograms' preference, but got: \(current)")
        }
    }
    
    @Test("Current weight unit defaults to pounds for invalid preference")
    func testInvalidPreferenceDefaultsToPounds() {
        withTestUserDefaults { testUserDefaults in
            testUserDefaults.set("InvalidUnit", forKey: WeightUnitPreference.storageKey)
            
            let current = WeightUnitPreference.current
            #expect(current == .pounds, "Should default to pounds for invalid preference")
        }
    }
}

@Suite("InventoryItemType Color Tests")
struct InventoryItemTypeColorTests {
    
    @Test("InventoryItemType has correct colors")
    func testColors() {
        // Import SwiftUI to access Color type
        let inventoryColor = InventoryItemType.inventory.color
        let buyColor = InventoryItemType.buy.color
        let sellColor = InventoryItemType.sell.color
        
        // Test that colors are not nil and are different from each other
        #expect(inventoryColor != buyColor, "Inventory and buy should have different colors")
        #expect(inventoryColor != sellColor, "Inventory and sell should have different colors") 
        #expect(buyColor != sellColor, "Buy and sell should have different colors")
    }
}

@Suite("ImageHelpers Advanced Tests")
struct ImageHelpersAdvancedTests {
    
    @Test("Product image exists returns false for empty item code")
    func testProductImageExistsWithEmptyCode() {
        let exists = ImageHelpers.productImageExists(for: "", manufacturer: nil)
        #expect(exists == false, "Should return false for empty item code")
    }
    
    @Test("Product image exists returns false for empty item code with manufacturer")
    func testProductImageExistsWithEmptyCodeAndManufacturer() {
        let exists = ImageHelpers.productImageExists(for: "", manufacturer: "TestMfg")
        #expect(exists == false, "Should return false for empty item code even with manufacturer")
    }
    
    @Test("Load product image returns nil for empty item code")
    func testLoadProductImageWithEmptyCode() {
        let image = ImageHelpers.loadProductImage(for: "", manufacturer: nil)
        #expect(image == nil, "Should return nil for empty item code")
    }
    
    @Test("Get product image name returns nil for empty item code")
    func testGetProductImageNameWithEmptyCode() {
        let imageName = ImageHelpers.getProductImageName(for: "", manufacturer: nil)
        #expect(imageName == nil, "Should return nil for empty item code")
    }
}
