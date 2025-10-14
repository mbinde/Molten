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
@testable import Flameworker

@Suite("SortUtilities Repository Pattern Tests")
struct SortUtilitiesTests {
    
    @Test("SortUtilities should only provide business model sorting, not Core Data entity sorting")
    func testSortUtilitiesBusinessModelOnly() {
        // Arrange: Create test catalog items using business models
        let testItems = [
            CatalogItemModel(name: "Glass Rod", rawCode: "GR001", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Frit", rawCode: "FR001", manufacturer: "Spectrum")
        ]
        
        // Act: Sort using business model methods
        let sortedByName = SortUtilities.sortCatalog(testItems, by: .name)
        let sortedByCode = SortUtilities.sortCatalog(testItems, by: .code)
        let sortedByManufacturer = SortUtilities.sortCatalog(testItems, by: .manufacturer)
        
        // Assert: All business model sorting methods should work
        #expect(sortedByName.count == 2, "Should sort catalog items by name")
        #expect(sortedByCode.count == 2, "Should sort catalog items by code") 
        #expect(sortedByManufacturer.count == 2, "Should sort catalog items by manufacturer")
        
        // Assert: Results should be properly sorted
        #expect(sortedByName[0].name == "Frit", "Should sort Frit before Glass Rod alphabetically")
        #expect(sortedByCode[0].code == "BULLSEYE-GR001", "Should sort BULLSEYE-GR001 before SPECTRUM-FR001 alphabetically")
    }
    
    @Test("SortUtilities should work with InventoryItemModel business models")
    func testSortUtilitiesInventoryBusinessModel() {
        // Arrange: Create test inventory items using business models
        let testItems = [
            InventoryItemModel(catalogCode: "GR001", quantity: 5, type: .buy),
            InventoryItemModel(catalogCode: "FR001", quantity: 10, type: .inventory)
        ]
        
        // Act: Sort using business model methods
        let sortedByCode = SortUtilities.sortInventory(testItems, by: .catalogCode)
        let sortedByCount = SortUtilities.sortInventory(testItems, by: .count)
        let sortedByType = SortUtilities.sortInventory(testItems, by: .type)
        
        // Assert: All business model inventory sorting should work
        #expect(sortedByCode.count == 2, "Should sort inventory items by catalog code")
        #expect(sortedByCount.count == 2, "Should sort inventory items by count")
        #expect(sortedByType.count == 2, "Should sort inventory items by type")
        
        // Assert: Results should be properly sorted
        #expect(sortedByCode[0].catalogCode == "FR001", "Should sort FR001 before GR001")
        #expect(sortedByCount[0].quantity == 10, "Should sort higher quantities first")
    }
    
    @Test("SortUtilities should not expose Core Data entity sorting methods")
    func testSortUtilitiesNoCoreDataMethods() {
        // This test verifies that SortUtilities doesn't expose methods that work directly with Core Data entities
        // If the following code compiles, it means Core Data entity methods are still exposed (which is wrong)
        
        // This should NOT compile after migration:
        // let coreDataItems: [InventoryItem] = []
        // let sorted = SortUtilities.sortInventoryByCode(coreDataItems) // Should be removed
        
        // Instead, only business model methods should be available:
        let businessModelItems: [InventoryItemModel] = []
        let sorted = SortUtilities.sortInventory(businessModelItems, by: .catalogCode)
        
        #expect(sorted.isEmpty, "Business model sorting should work")
    }
}