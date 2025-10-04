//
//  InventoryServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("InventoryService Tests")
struct InventoryServiceTests {
    
    @Test("Should create inventory item without units parameter")
    func testCreateInventoryItemWithoutUnits() throws {
        let context = PersistenceController.preview.container.viewContext
        let service = InventoryService.shared
        
        // Should be able to create item without units parameter since units are on CatalogItem
        let item = try service.createInventoryItem(
            id: "test-item",
            catalogCode: "TEST-001",
            count: 25.0,
            type: InventoryItemType.sell.rawValue,
            notes: "Test item",
            in: context
        )
        
        #expect(item.id == "test-item")
        #expect(item.catalog_code == "TEST-001")
        #expect(item.count == 25.0)
        #expect(item.type == InventoryItemType.sell.rawValue)
        #expect(item.notes == "Test item")
    }
    
    @Test("Should update inventory item without units parameter")
    func testUpdateInventoryItemWithoutUnits() throws {
        let context = PersistenceController.preview.container.viewContext
        let service = InventoryService.shared
        
        // Create initial item
        let item = try service.createInventoryItem(
            id: "test-update",
            catalogCode: "TEST-002",
            count: 10.0,
            in: context
        )
        
        // Should be able to update without units parameter
        try service.updateInventoryItem(
            item,
            catalogCode: "TEST-002-UPDATED",
            count: 15.0,
            type: InventoryItemType.buy.rawValue,
            notes: "Updated notes",
            in: context
        )
        
        #expect(item.catalog_code == "TEST-002-UPDATED")
        #expect(item.count == 15.0)
        #expect(item.type == InventoryItemType.buy.rawValue)
        #expect(item.notes == "Updated notes")
    }
}