//  WeightUnitTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("Weight Unit Tests")
struct WeightUnitTests {
    
    @Test("WeightUnit display properties")
    func weightUnitDisplayProperties() {
        let pounds = WeightUnit.pounds
        let kilograms = WeightUnit.kilograms
        
        #expect(pounds.displayName == "Pounds")
        #expect(pounds.symbol == "lb")
        #expect(kilograms.displayName == "Kilograms")
        #expect(kilograms.symbol == "kg")
    }
    
    @Test("WeightUnitPreference defaults to pounds")
    func weightUnitPreferenceDefaults() {
        // Clear any existing preference
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
        
        let currentUnit = WeightUnitPreference.current
        #expect(currentUnit == .pounds)
    }
    
    @Test("WeightUnitPreference reads from DefaultUnits setting")
    func weightUnitPreferenceReadsFromSettings() {
        // Test pounds setting
        UserDefaults.standard.set("Pounds", forKey: "defaultUnits")
        #expect(WeightUnitPreference.current == .pounds)
        
        // Test kilograms setting
        UserDefaults.standard.set("Kilograms", forKey: "defaultUnits")
        #expect(WeightUnitPreference.current == .kilograms)
        
        // Test invalid setting falls back to pounds
        UserDefaults.standard.set("InvalidUnit", forKey: "defaultUnits")
        #expect(WeightUnitPreference.current == .pounds)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
    }
    
    @Test("InventoryUnits displays correct unit names")
    func inventoryUnitsDisplaysCorrectUnitNames() {
        let poundsUnit = InventoryUnits.pounds
        let kilogramsUnit = InventoryUnits.kilograms
        let shortsUnit = InventoryUnits.shorts
        let rodsUnit = InventoryUnits.rods
        
        #expect(poundsUnit.displayName == "Pounds")
        #expect(kilogramsUnit.displayName == "Kilograms")
        #expect(shortsUnit.displayName == "Shorts")
        #expect(rodsUnit.displayName == "Rods")
    }
    
    @Test("UnitsDisplayHelper provides short symbols for weight units")
    func unitsDisplayHelperProvidesShortSymbolsForWeightUnits() {
        let poundsUnit = InventoryUnits.pounds
        let kilogramsUnit = InventoryUnits.kilograms
        let shortsUnit = InventoryUnits.shorts
        let rodsUnit = InventoryUnits.rods
        
        #expect(UnitsDisplayHelper.displayName(for: poundsUnit) == "lb")
        #expect(UnitsDisplayHelper.displayName(for: kilogramsUnit) == "kg")
        #expect(UnitsDisplayHelper.displayName(for: shortsUnit) == "Shorts")
        #expect(UnitsDisplayHelper.displayName(for: rodsUnit) == "Rods")
    }
    
    @Test("UnitsDisplayHelper returns preferred weight unit from settings")
    func unitsDisplayHelperReturnsPreferredWeightUnitFromSettings() {
        // Test pounds preference
        UserDefaults.standard.set("Pounds", forKey: "defaultUnits")
        #expect(UnitsDisplayHelper.preferredWeightUnit() == .pounds)
        
        // Test kilograms preference
        UserDefaults.standard.set("Kilograms", forKey: "defaultUnits")
        #expect(UnitsDisplayHelper.preferredWeightUnit() == .kilograms)
        
        // Test default when no preference set
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
        #expect(UnitsDisplayHelper.preferredWeightUnit() == .pounds)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
    }
    
    @Test("WeightUnit conversion works correctly")
    func weightUnitConversionWorksCorrectly() {
        let pounds = WeightUnit.pounds
        let kilograms = WeightUnit.kilograms
        
        // Test pounds to kilograms
        let poundsToKg = pounds.convert(10.0, to: .kilograms)
        #expect(abs(poundsToKg - 4.53592) < 0.001, "10 lbs should convert to ~4.536 kg")
        
        // Test kilograms to pounds
        let kgToPounds = kilograms.convert(5.0, to: .pounds)
        #expect(abs(kgToPounds - 11.0231) < 0.001, "5 kg should convert to ~11.023 lbs")
        
        // Test no conversion when units are the same
        #expect(pounds.convert(10.0, to: .pounds) == 10.0)
        #expect(kilograms.convert(5.0, to: .kilograms) == 5.0)
    }
    
    @Test("UnitsDisplayHelper provides correct display info for weight conversion")
    func unitsDisplayHelperProvidesCorrectDisplayInfoForWeightConversion() {
        // Create a test persistence controller
        let testContext = TestUtilities.createTestPersistenceController().container.viewContext
        
        // Create test inventory items
        let poundsItem = InventoryItem(context: testContext)
        poundsItem.count = 10.0
        poundsItem.units = InventoryUnits.pounds.rawValue
        
        let kilogramsItem = InventoryItem(context: testContext)
        kilogramsItem.count = 5.0
        kilogramsItem.units = InventoryUnits.kilograms.rawValue
        
        let shortsItem = InventoryItem(context: testContext)
        shortsItem.count = 20.0
        shortsItem.units = InventoryUnits.shorts.rawValue
        
        // Test conversion when preference is pounds
        UserDefaults.standard.set("Pounds", forKey: "defaultUnits")
        
        let poundsDisplayInfo = UnitsDisplayHelper.displayInfo(for: poundsItem)
        #expect(poundsDisplayInfo.count == 10.0, "Pounds item should remain 10.0 when preference is pounds")
        #expect(poundsDisplayInfo.unit == "lb")
        
        let kilogramsDisplayInfo = UnitsDisplayHelper.displayInfo(for: kilogramsItem)
        #expect(abs(kilogramsDisplayInfo.count - 11.0231) < 0.001, "5 kg should convert to ~11.023 lbs")
        #expect(kilogramsDisplayInfo.unit == "lb")
        
        let shortsDisplayInfo = UnitsDisplayHelper.displayInfo(for: shortsItem)
        #expect(shortsDisplayInfo.count == 20.0, "Non-weight units should not be converted")
        #expect(shortsDisplayInfo.unit == "Shorts")
        
        // Test conversion when preference is kilograms
        UserDefaults.standard.set("Kilograms", forKey: "defaultUnits")
        
        let poundsDisplayInfoKg = UnitsDisplayHelper.displayInfo(for: poundsItem)
        #expect(abs(poundsDisplayInfoKg.count - 4.53592) < 0.001, "10 lbs should convert to ~4.536 kg")
        #expect(poundsDisplayInfoKg.unit == "kg")
        
        let kilogramsDisplayInfoKg = UnitsDisplayHelper.displayInfo(for: kilogramsItem)
        #expect(kilogramsDisplayInfoKg.count == 5.0, "Kilograms item should remain 5.0 when preference is kg")
        #expect(kilogramsDisplayInfoKg.unit == "kg")
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
    }
    
    @Test("InventoryItem convenience methods work correctly")
    func inventoryItemConvenienceMethodsWorkCorrectly() {
        // Create a test persistence controller
        let testContext = TestUtilities.createTestPersistenceController().container.viewContext
        
        // Create a test inventory item with pounds
        let poundsItem = InventoryItem(context: testContext)
        poundsItem.count = 10.0
        poundsItem.units = InventoryUnits.pounds.rawValue
        
        // Test conversion when preference is kilograms
        UserDefaults.standard.set("Kilograms", forKey: "defaultUnits")
        
        let displayInfo = poundsItem.displayInfo
        #expect(abs(displayInfo.count - 4.53592) < 0.001, "10 lbs should convert to ~4.536 kg")
        #expect(displayInfo.unit == "kg")
        
        let formattedString = poundsItem.formattedCountWithUnits
        #expect(formattedString.contains("4.5"))
        #expect(formattedString.contains("kg"))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "defaultUnits")
    }
}