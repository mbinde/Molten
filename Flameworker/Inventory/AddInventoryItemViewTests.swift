//
//  AddInventoryItemViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import SwiftUI
import CoreData
@testable import Flameworker

@Suite("AddInventoryItemView Tests")
struct AddInventoryItemViewTests {
    
    @Test("Should use units from catalog item when adding inventory")
    func testUseCatalogItemUnitsWhenAdding() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a catalog item with specific units
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "TEST-UNITS-001"
        catalogItem.code = "TEST-UNITS-001"
        catalogItem.name = "Glass Rod Test"
        catalogItem.units = InventoryUnits.ounces.rawValue
        
        // When adding inventory for this catalog item, should use ounces
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.catalog_code = "TEST-UNITS-001"
        inventoryItem.count = 10.0
        inventoryItem.type = InventoryItemType.inventory.rawValue
        
        // Should get units from catalog item
        let displayUnits = inventoryItem.unitsKind
        #expect(displayUnits == .ounces, "Should use units from catalog item")
        #expect(inventoryItem.unitsDisplayName == "oz", "Should display ounces")
    }
    
    @Test("Should fallback to rods when catalog item has no units")
    func testFallbackToRodsWhenNoUnits() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a catalog item with uninitialized units (0)
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "TEST-NO-UNITS-001"
        catalogItem.code = "TEST-NO-UNITS-001"
        catalogItem.name = "Glass Item No Units"
        catalogItem.units = 0 // Uninitialized
        
        // When adding inventory for this catalog item, should fallback to rods
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.catalog_code = "TEST-NO-UNITS-001"
        inventoryItem.count = 5.0
        inventoryItem.type = InventoryItemType.inventory.rawValue
        
        // Should fallback to rods
        let displayUnits = inventoryItem.unitsKind
        #expect(displayUnits == .rods, "Should fallback to rods when catalog item has no units")
        #expect(inventoryItem.unitsDisplayName == "Rods", "Should display Rods as fallback")
    }
    
    @Test("Should fallback to rods when catalog item doesn't exist")
    func testFallbackToRodsWhenCatalogNotFound() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create inventory item with non-existent catalog code
        let inventoryItem = InventoryItem(context: context)
        inventoryItem.catalog_code = "NONEXISTENT-CODE"
        inventoryItem.count = 3.0
        inventoryItem.type = InventoryItemType.inventory.rawValue
        
        // Should fallback to rods when catalog item not found
        let displayUnits = inventoryItem.unitsKind
        #expect(displayUnits == .rods, "Should fallback to rods when catalog item not found")
        #expect(inventoryItem.unitsDisplayName == "Rods", "Should display Rods as fallback")
    }
}