//  InventoryTestsSupplemental.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
@testable import Flameworker

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
            Issue.record("Failed to create test UserDefaults")
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
            Issue.record("Failed to create test UserDefaults")
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