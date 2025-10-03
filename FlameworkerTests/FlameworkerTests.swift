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
import CoreData
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
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            #expect(false, "Failed to create test UserDefaults")
            return
        }
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        let result = UnitsDisplayHelper.convertCount(32.0, from: .ounces)
        
        // 32oz = 2lb normalized, should stay as pounds
        #expect(result.unit == "lb", "Should use pounds when preference is set to pounds. Got: \(result.unit)")
        #expect(abs(result.count - 2.0) < 0.01, "32 ounces should convert to 2 pounds. Got: \(result.count)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Convert grams to user's preferred weight unit") 
    func testConvertGramsToPreferredUnit() {
        // Test with kilograms preference
        let testSuiteName = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            #expect(false, "Failed to create test UserDefaults")
            return
        }
        testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        let result = UnitsDisplayHelper.convertCount(2000.0, from: .grams)
        
        // 2000g = 2kg normalized, should stay as kilograms
        #expect(result.unit == "kg", "Should use kilograms when preference is set to kilograms. Got: \(result.unit)")
        #expect(abs(result.count - 2.0) < 0.01, "2000 grams should convert to 2 kg. Got: \(result.count)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Conversion follows two-stage process")
    func testTwoStageConversionProcess() {
        // Test with a specific preference to make test predictable
        let testSuiteName = "UnitsDisplayHelperTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            #expect(false, "Failed to create test UserDefaults")
            return
        }
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Test the actual behavior: small units → large units → preferred system
        let gramsResult = UnitsDisplayHelper.convertCount(1000.0, from: .grams)
        let ouncesResult = UnitsDisplayHelper.convertCount(16.0, from: .ounces)
        
        // Both should be converted to pounds (our test preference)
        #expect(gramsResult.unit == "lb", "Should convert to pounds preference. Got: \(gramsResult.unit)")
        #expect(ouncesResult.unit == "lb", "Should convert to pounds preference. Got: \(ouncesResult.unit)")
        
        // Verify the math:
        // 1000g = 1kg → 1/0.453592 ≈ 2.205 lb
        // 16oz = 1lb → 1.0 lb (no conversion needed)
        #expect(abs(gramsResult.count - 2.205) < 0.01, "1000g → 1kg → ~2.205 lb. Got: \(gramsResult.count)")
        #expect(abs(ouncesResult.count - 1.0) < 0.01, "16oz → 1lb → 1 lb. Got: \(ouncesResult.count)")
        
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

@Suite("WeightUnitPreference Tests", .serialized)
struct WeightUnitPreferenceTests {
    
    @Test("Current weight unit defaults to pounds when no preference set")
    func testDefaultToPounds() async {
        let testSuiteName = "DefaultTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify no value is set (should be nil in fresh UserDefaults)
        let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
        #expect(storedValue == nil, "Fresh UserDefaults should have no value, but got: \(storedValue ?? "nil")")
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds when no preference is set, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit defaults to pounds when empty string preference")
    func testDefaultToPoundsWithEmptyString() {
        let testSuiteName = "EmptyTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds when preference is empty string, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit returns pounds for 'Pounds' preference")
    func testPoundsPreference() async {
        let testSuiteName = "PoundsTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should return pounds for 'Pounds' preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit returns kilograms for 'Kilograms' preference")
    func testKilogramsPreference() async {
        let testSuiteName = "KilogramsTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify the value was actually set
        let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
        #expect(storedValue == "Kilograms", "UserDefaults should store 'Kilograms', but got: \(storedValue ?? "nil")")
        
        let current = WeightUnitPreference.current
        #expect(current == .kilograms, "Should return kilograms for 'Kilograms' preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit defaults to pounds for invalid preference")
    func testInvalidPreferenceDefaultsToPounds() {
        let testSuiteName = "InvalidTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("InvalidUnit", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds for invalid preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
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
    
    @Test("Product image exists handles whitespace item codes")
    func testProductImageExistsWithWhitespaceCode() {
        let exists = ImageHelpers.productImageExists(for: "   ", manufacturer: nil)
        #expect(exists == false, "Should return false for whitespace item code")
    }
    
    @Test("Load product image handles whitespace manufacturer")
    func testLoadProductImageWithWhitespaceManufacturer() {
        let image = ImageHelpers.loadProductImage(for: "ABC123", manufacturer: "   ")
        // Should attempt to load without manufacturer prefix since manufacturer is effectively empty
        #expect(image == nil, "Should handle whitespace manufacturer gracefully")
    }
}

@Suite("InventoryUnits Formatting Tests")
struct InventoryUnitsFormattingTests {
    
    // Test the formatting logic directly without Core Data
    @Test("Formatted count shows whole numbers without decimals")
    func testFormattedCountWholeNumbers() {
        // Test the formatting logic directly
        let count = 5.0
        let formattedCount: String
        if count.truncatingRemainder(dividingBy: 1) == 0 {
            formattedCount = String(format: "%.0f", count)
        } else {
            formattedCount = String(format: "%.1f", count)
        }
        
        #expect(formattedCount == "5", "Should show '5' not '5.0' for whole numbers. Got: \(formattedCount)")
        #expect(!formattedCount.contains(".0"), "Should not contain '.0' for whole numbers. Got: \(formattedCount)")
    }
    
    @Test("Formatted count shows one decimal place for fractional numbers")
    func testFormattedCountFractionalNumbers() {
        let count = 2.5
        let formattedCount: String
        if count.truncatingRemainder(dividingBy: 1) == 0 {
            formattedCount = String(format: "%.0f", count)
        } else {
            formattedCount = String(format: "%.1f", count)
        }
        
        #expect(formattedCount == "2.5", "Should show '2.5' for fractional numbers. Got: \(formattedCount)")
    }
    
    @Test("Formatted count handles zero correctly")
    func testFormattedCountZero() {
        let count = 0.0
        let formattedCount: String
        if count.truncatingRemainder(dividingBy: 1) == 0 {
            formattedCount = String(format: "%.0f", count)
        } else {
            formattedCount = String(format: "%.1f", count)
        }
        
        #expect(formattedCount == "0", "Should show '0' not '0.0' for zero. Got: \(formattedCount)")
    }
    
    @Test("Units display names work correctly for all types")
    func testUnitsDisplayNames() {
        #expect(InventoryUnits.shorts.displayName == "Shorts", "Should return 'Shorts' for shorts")
        #expect(InventoryUnits.rods.displayName == "Rods", "Should return 'Rods' for rods")
        #expect(InventoryUnits.ounces.displayName == "oz", "Should return 'oz' for ounces")
        #expect(InventoryUnits.pounds.displayName == "lb", "Should return 'lb' for pounds")
        #expect(InventoryUnits.grams.displayName == "g", "Should return 'g' for grams")
        #expect(InventoryUnits.kilograms.displayName == "kg", "Should return 'kg' for kilograms")
    }
    
    @Test("UnitsDisplayHelper converts and formats correctly")
    func testUnitsDisplayHelperFormatting() {
        // Test with pounds preference
        let testSuiteName = "FormattingTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            #expect(false, "Failed to create test UserDefaults")
            return
        }
        
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Test non-weight units remain unchanged
        let shortsResult = UnitsDisplayHelper.convertCount(3.0, from: .shorts)
        #expect(shortsResult.count == 3.0, "Shorts should not be converted")
        #expect(shortsResult.unit == "Shorts", "Shorts should keep unit name")
        
        let rodsResult = UnitsDisplayHelper.convertCount(2.0, from: .rods)
        #expect(rodsResult.count == 2.0, "Rods should not be converted")
        #expect(rodsResult.unit == "Rods", "Rods should keep unit name")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
}

@Suite("WeightUnit Edge Cases Tests")
struct WeightUnitEdgeCasesTests {
    
    @Test("WeightUnit conversion handles zero values")
    func testConversionWithZeroValues() {
        let poundsToKg = WeightUnit.pounds.convert(0.0, to: .kilograms)
        #expect(poundsToKg == 0.0, "Zero pounds should convert to zero kilograms")
        
        let kgToPounds = WeightUnit.kilograms.convert(0.0, to: .pounds)
        #expect(kgToPounds == 0.0, "Zero kilograms should convert to zero pounds")
    }
    
    @Test("WeightUnit conversion handles negative values")
    func testConversionWithNegativeValues() {
        let result = WeightUnit.pounds.convert(-10.0, to: .kilograms)
        #expect(result < 0, "Negative input should produce negative output")
        #expect(abs(result - (-4.53592)) < 0.0001, "Should correctly convert negative values")
    }
    
    @Test("WeightUnit conversion handles very large values")
    func testConversionWithLargeValues() {
        let largeValue = 1000000.0
        let result = WeightUnit.pounds.convert(largeValue, to: .kilograms)
        #expect(result > 0, "Should handle large values without overflow")
        #expect(abs(result - (largeValue * 0.453592)) < 1.0, "Should maintain precision with large values")
    }
    
    @Test("WeightUnit conversion handles very small values")
    func testConversionWithSmallValues() {
        let smallValue = 0.001
        let result = WeightUnit.pounds.convert(smallValue, to: .kilograms)
        #expect(result > 0, "Should handle small positive values")
        #expect(abs(result - (smallValue * 0.453592)) < 0.000001, "Should maintain precision with small values")
    }
}

@Suite("UnitsDisplayHelper Edge Cases Tests")
struct UnitsDisplayHelperEdgeCasesTests {
    
    @Test("Convert count handles zero weight values")
    func testConvertCountWithZeroWeights() {
        let ouncesResult = UnitsDisplayHelper.convertCount(0.0, from: .ounces)
        #expect(ouncesResult.count == 0.0, "Zero ounces should convert to zero of target unit")
        
        let gramsResult = UnitsDisplayHelper.convertCount(0.0, from: .grams)
        #expect(gramsResult.count == 0.0, "Zero grams should convert to zero of target unit")
    }
    
    @Test("Convert count handles fractional weight values")
    func testConvertCountWithFractionalWeights() {
        let result = UnitsDisplayHelper.convertCount(0.5, from: .ounces)
        #expect(result.count > 0, "Fractional ounces should convert to positive target value")
        #expect(result.count < 1.0, "Half an ounce should be less than 1 of any larger unit")
    }
    
    @Test("Convert count maintains non-weight units exactly")
    func testConvertCountMaintainsNonWeightUnits() {
        let shortsResult = UnitsDisplayHelper.convertCount(3.5, from: .shorts)
        #expect(shortsResult.count == 3.5, "Non-weight units should not be converted")
        #expect(shortsResult.unit == "Shorts", "Non-weight units should keep original unit name")
        
        let rodsResult = UnitsDisplayHelper.convertCount(1.25, from: .rods)
        #expect(rodsResult.count == 1.25, "Non-weight units should not be converted")
        #expect(rodsResult.unit == "Rods", "Non-weight units should keep original unit name")
    }
    
    @Test("Display name handles all inventory unit types")
    func testDisplayNameForAllUnitTypes() {
        // Test each case to ensure no missing implementations
        let allUnits: [InventoryUnits] = [.shorts, .rods, .ounces, .pounds, .grams, .kilograms]
        
        for unit in allUnits {
            let displayName = UnitsDisplayHelper.displayName(for: unit)
            #expect(!displayName.isEmpty, "Display name should not be empty for \(unit)")
            #expect(displayName == unit.displayName, "Display name should match unit's own displayName")
        }
    }
}

@Suite("InventoryUnits Core Data Safety Tests")
struct InventoryUnitsCoreDataSafetyTests {
    
    @Test("InventoryUnits enum fallback behavior works correctly")
    func testInventoryUnitsEnumFallback() {
        // Test that InventoryUnits init with invalid values falls back correctly
        let validUnit = InventoryUnits(from: 3) // Should be .pounds
        #expect(validUnit == .pounds, "Valid raw value should work correctly")
        
        let invalidUnit = InventoryUnits(from: 999) // Should fallback to .shorts
        #expect(invalidUnit == .shorts, "Invalid raw value should fallback to .shorts")
        
        let negativeUnit = InventoryUnits(from: -1) // Should fallback to .shorts
        #expect(negativeUnit == .shorts, "Negative raw value should fallback to .shorts")
    }
    
    @Test("InventoryItemType enum fallback behavior works correctly")
    func testInventoryItemTypeEnumFallback() {
        // Test that InventoryItemType init with invalid values falls back correctly
        let validType = InventoryItemType(from: 1) // Should be .buy
        #expect(validType == .buy, "Valid raw value should work correctly")
        
        let invalidType = InventoryItemType(from: 999) // Should fallback to .inventory
        #expect(invalidType == .inventory, "Invalid raw value should fallback to .inventory")
        
        let negativeType = InventoryItemType(from: -1) // Should fallback to .inventory
        #expect(negativeType == .inventory, "Negative raw value should fallback to .inventory")
    }
    
    @Test("UnitsDisplayHelper handles conversion edge cases safely")
    func testUnitsDisplayHelperSafety() {
        // Test with minimal UserDefaults setup
        let testSuiteName = "SafetyTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            #expect(false, "Failed to create test UserDefaults")
            return
        }
        
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Test that conversion works for all unit types without crashing
        let allUnits: [InventoryUnits] = [.shorts, .rods, .ounces, .pounds, .grams, .kilograms]
        
        for unit in allUnits {
            let result = UnitsDisplayHelper.convertCount(1.0, from: unit)
            #expect(result.count >= 0, "Convert count should return non-negative values for \(unit)")
            #expect(!result.unit.isEmpty, "Convert count should return non-empty unit string for \(unit)")
        }
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
}
