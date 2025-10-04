//
//  InventoryUnitsFixTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("InventoryUnits Fix Tests")
struct InventoryUnitsFixTests {
    
    @Test("Should access catalog item units without optional binding")
    func testCatalogItemUnitsAccess() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a catalog item with units
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "test-catalog"
        catalogItem.code = "TEST-001"
        catalogItem.name = "Test Item"
        catalogItem.units = InventoryUnits.ounces.rawValue
        
        // Create an inventory item linked to the catalog item
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.id = "test-inventory"
        inventoryItem.catalog_code = "TEST-001"
        inventoryItem.count = 50.0
        inventoryItem.type = InventoryItemType.sell.rawValue
        
        // Should be able to access units without compilation error
        let units = inventoryItem.unitsKind
        
        #expect(units == .ounces, "Should return ounces from catalog item")
        #expect(inventoryItem.unitsDisplayName == "oz", "Should display ounces abbreviation")
    }
}