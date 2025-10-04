//
//  InventoryItemRowViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import SwiftUI
import CoreData
@testable import Flameworker

@Suite("InventoryItemRowView Tests")
struct InventoryItemRowViewTests {
    
    @Test("Should display formatted count with units from catalog item")
    func testFormattedCountWithUnitsFromCatalogItem() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a catalog item with units
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "test-catalog"
        catalogItem.code = "TEST-001"
        catalogItem.name = "Test Glass Rod"
        catalogItem.units = InventoryUnits.rods.rawValue
        
        // Create an inventory item linked to the catalog item
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.id = "test-inventory"
        inventoryItem.catalog_code = "TEST-001"
        inventoryItem.count = 50.0
        inventoryItem.type = InventoryItemType.sell.rawValue
        
        // The formatted count should use units from the catalog item
        let formatted = inventoryItem.formattedCountWithUnits
        
        #expect(formatted.contains("Rods"), "Should display units from catalog item")
        #expect(formatted.contains("50"), "Should display the count")
    }
    
    @Test("Should handle missing catalog item gracefully")
    func testFormattedCountWithoutCatalogItem() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create an inventory item without a linked catalog item
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.id = "test-inventory"
        inventoryItem.catalog_code = "NONEXISTENT"
        inventoryItem.count = 25.0
        inventoryItem.type = InventoryItemType.buy.rawValue
        
        // Should handle missing catalog item gracefully
        let formatted = inventoryItem.formattedCountWithUnits
        
        #expect(!formatted.isEmpty, "Should return some formatted string")
        #expect(formatted.contains("25"), "Should display the count")
    }
}