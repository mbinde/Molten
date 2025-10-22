//
//  SortUtilitiesTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Molten

@Suite("SortUtilities GlassItem Architecture Tests")
@MainActor
struct SortUtilitiesTests {
    
    @Test("SortUtilities should sort GlassItemModel by different criteria")
    func testSortGlassItems() {
        // Arrange: Create test glass items using current architecture
        let testItems = [
            GlassItemModel(natural_key: "bullseye-gr001-0", name: "Glass Rod", sku: "GR001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-fr001-0", name: "Frit", sku: "FR001", manufacturer: "Spectrum", coe: 96, mfr_status: "available")
        ]
        
        // Act: Sort using GlassItem methods
        let sortedByName = SortUtilities.sortGlassItems(testItems, by: .name)
        let sortedByNaturalKey = SortUtilities.sortGlassItems(testItems, by: .natural_key)
        let sortedByManufacturer = SortUtilities.sortGlassItems(testItems, by: .manufacturer)
        let sortedByCOE = SortUtilities.sortGlassItems(testItems, by: .coe)
        let sortedBySKU = SortUtilities.sortGlassItems(testItems, by: .sku)
        
        // Assert: All sorting methods should work
        #expect(sortedByName.count == 2, "Should sort glass items by name")
        #expect(sortedByNaturalKey.count == 2, "Should sort glass items by natural key")
        #expect(sortedByManufacturer.count == 2, "Should sort glass items by manufacturer")
        #expect(sortedByCOE.count == 2, "Should sort glass items by COE")
        #expect(sortedBySKU.count == 2, "Should sort glass items by SKU")
        
        // Assert: Results should be properly sorted
        #expect(sortedByName[0].name == "Frit", "Should sort Frit before Glass Rod alphabetically")
        #expect(sortedByNaturalKey[0].natural_key == "bullseye-gr001-0", "Should sort bullseye-gr001-0 before spectrum-fr001-0 alphabetically")
        #expect(sortedByCOE[0].coe == 90, "Should sort lower COE values first")
    }
    
    @Test("SortUtilities should sort InventoryModel by different criteria")
    func testSortInventoryModels() {
        // Arrange: Create test inventory items using current architecture
        let testItems = [
            InventoryModel(item_natural_key: "bullseye-gr001-0", type: "rod", quantity: 5.0),
            InventoryModel(item_natural_key: "spectrum-fr001-0", type: "frit", quantity: 10.0)
        ]
        
        // Act: Sort using inventory methods
        let sortedByKey = SortUtilities.sortInventoryModels(testItems, by: .item_natural_key)
        let sortedByQuantity = SortUtilities.sortInventoryModels(testItems, by: .quantity)
        let sortedByType = SortUtilities.sortInventoryModels(testItems, by: .type)
        
        // Assert: All inventory sorting should work
        #expect(sortedByKey.count == 2, "Should sort inventory items by natural key")
        #expect(sortedByQuantity.count == 2, "Should sort inventory items by quantity")
        #expect(sortedByType.count == 2, "Should sort inventory items by type")
        
        // Assert: Results should be properly sorted
        #expect(sortedByKey[0].item_natural_key == "bullseye-gr001-0", "Should sort bullseye before spectrum")
        #expect(sortedByQuantity[0].quantity == 10.0, "Should sort higher quantities first")
        #expect(sortedByType[0].type == "frit", "Should sort frit before rod alphabetically")
    }
    
    @Test("SortUtilities should sort CompleteInventoryItemModel by glass item criteria")
    func testSortCompleteInventoryItems() {
        // Arrange: Create test complete inventory items
        let glassItem1 = GlassItemModel(natural_key: "bullseye-gr001-0", name: "Glass Rod", sku: "GR001", manufacturer: "Bullseye", coe: 90, mfr_status: "available")
        let glassItem2 = GlassItemModel(natural_key: "spectrum-fr001-0", name: "Frit", sku: "FR001", manufacturer: "Spectrum", coe: 96, mfr_status: "available")
        
        let testItems = [
            CompleteInventoryItemModel(glassItem: glassItem1, inventory: [], tags: [], userTags: [], locations: []),
            CompleteInventoryItemModel(glassItem: glassItem2, inventory: [], tags: [], userTags: [], locations: [])
        ]
        
        // Act: Sort using complete inventory methods
        let sortedByName = SortUtilities.sortCompleteInventoryItems(testItems, by: .name)
        let sortedByNaturalKey = SortUtilities.sortCompleteInventoryItems(testItems, by: .natural_key)
        let sortedByManufacturer = SortUtilities.sortCompleteInventoryItems(testItems, by: .manufacturer)
        let sortedByCOE = SortUtilities.sortCompleteInventoryItems(testItems, by: .coe)
        
        // Assert: All complete inventory sorting should work
        #expect(sortedByName.count == 2, "Should sort complete items by name")
        #expect(sortedByNaturalKey.count == 2, "Should sort complete items by natural key")
        #expect(sortedByManufacturer.count == 2, "Should sort complete items by manufacturer")
        #expect(sortedByCOE.count == 2, "Should sort complete items by COE")
        
        // Assert: Results should be properly sorted
        #expect(sortedByName[0].glassItem.name == "Frit", "Should sort Frit before Glass Rod alphabetically")
        #expect(sortedByCOE[0].glassItem.coe == 90, "Should sort lower COE values first")
    }
    
    @Test("SortUtilities should work with protocol-based generic sorting")
    func testProtocolBasedSorting() {
        // Arrange: Create test glass items
        let testItems = [
            GlassItemModel(natural_key: "bullseye-gr001-0", name: "Glass Rod", sku: "GR001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-fr001-0", name: "Frit", sku: "FR001", manufacturer: "Spectrum", coe: 96, mfr_status: "available")
        ]
        
        // Act: Sort using protocol-based generic method
        let sortedByName = SortUtilities.sortByGlassItemCriteria(testItems, by: .name)
        let sortedByNaturalKey = SortUtilities.sortByGlassItemCriteria(testItems, by: .natural_key)
        let sortedByManufacturer = SortUtilities.sortByGlassItemCriteria(testItems, by: .manufacturer)
        
        // Assert: Protocol-based sorting should work
        #expect(sortedByName.count == 2, "Should sort using protocol by name")
        #expect(sortedByNaturalKey.count == 2, "Should sort using protocol by natural key")
        #expect(sortedByManufacturer.count == 2, "Should sort using protocol by manufacturer")
        
        // Assert: Results should be properly sorted
        #expect(sortedByName[0].name == "Frit", "Should sort Frit before Glass Rod alphabetically")
    }
    
    @Test("SortUtilities deprecated methods should return unsorted arrays")
    func testDeprecatedMethods() {
        // Test that deprecated methods exist but return unsorted arrays
        let glassItems = [
            GlassItemModel(natural_key: "bullseye-gr001-0", name: "Glass Rod", sku: "GR001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-fr001-0", name: "Frit", sku: "FR001", manufacturer: "Spectrum", coe: 96, mfr_status: "available")
        ]
        
        let inventoryItems = [
            InventoryModel(item_natural_key: "bullseye-gr001-0", type: "rod", quantity: 5.0),
            InventoryModel(item_natural_key: "spectrum-fr001-0", type: "frit", quantity: 10.0)
        ]
        
        // These should work but return unsorted (for backward compatibility)
        let sortedCatalog = SortUtilities.sortCatalog(glassItems, by: "any")
        let sortedInventory = SortUtilities.sortInventory(inventoryItems, by: "any")
        
        #expect(sortedCatalog.count == 2, "Deprecated sortCatalog should return all items")
        #expect(sortedInventory.count == 2, "Deprecated sortInventory should return all items")
        
        // Should return items in original order (unsorted)
        #expect(sortedCatalog[0].name == "Glass Rod", "Deprecated methods return original order")
        #expect(sortedInventory[0].type == "rod", "Deprecated methods return original order")
    }
}
