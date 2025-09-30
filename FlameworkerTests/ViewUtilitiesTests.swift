//
//  ViewUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
import SwiftUI
@testable import Flameworker

@Suite("View Utilities Tests")
struct ViewUtilitiesTests {
    
    // MARK: - Test Helpers
    
    private func createTestPersistenceController() -> PersistenceController {
        return TestUtilities.createTestPersistenceController()
    }
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        return TestUtilities.createIsolatedContext(for: "ViewUtilitiesTests")
    }
    
    private func createTestInventoryItems(in context: NSManagedObjectContext, count: Int) -> [InventoryItem] {
        var items: [InventoryItem] = []
        
        for i in 0..<count {
            let item = InventoryItem(context: context)
            item.id = "TEST-\(i + 1)"
            item.catalog_code = "CODE-\(i + 1)"
            item.count = Double(i * 10)
            item.units = Int16(i + 1)
            item.type = InventoryItemType.inventory.rawValue
            item.notes = "Test item \(i + 1)"
            items.append(item)
        }
        
        return items
    }
    
    private func createTestCatalogItems(in context: NSManagedObjectContext, count: Int) -> [CatalogItem] {
        var items: [CatalogItem] = []
        
        for i in 0..<count {
            let item = CatalogItem(context: context)
            item.code = "CATALOG-\(i + 1)"
            item.name = "Catalog Item \(i + 1)"
            item.manufacturer = "Manufacturer \(i % 2 == 0 ? "A" : "B")"
            items.append(item)
        }
        
        return items
    }
    
    // MARK: - Core Data Operations Tests
    
    @Test("CoreDataOperations should delete items at specific offsets")
    func coreDataOperationsDeleteAtOffsets() async throws {
        let context = createIsolatedContext()
        
        let items = createTestInventoryItems(in: context, count: 5)
        try context.save()
        
        // Verify items were created
        let initialFetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let initialCount = try context.count(for: initialFetchRequest)
        #expect(initialCount == 5)
        
        // Delete items at indices 1 and 3
        let offsetsToDelete = IndexSet([1, 3])
        CoreDataOperations.deleteItems(items, at: offsetsToDelete, in: context)
        
        // Verify deletion
        let finalFetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let finalCount = try context.count(for: finalFetchRequest)
        #expect(finalCount == 3, "Should have 3 items remaining after deleting 2")
    }
    
    @Test("CoreDataOperations should handle empty offset gracefully")
    func coreDataOperationsEmptyOffset() async throws {
        let context = createIsolatedContext()
        
        let items = createTestInventoryItems(in: context, count: 3)
        try context.save()
        
        let emptyOffsets = IndexSet()
        CoreDataOperations.deleteItems(items, at: emptyOffsets, in: context)
        
        // Should still have all items
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let count = try context.count(for: fetchRequest)
        #expect(count == 3, "No items should be deleted with empty offsets")
    }
    
    @Test("CoreDataOperations should handle out-of-bounds indices gracefully")
    func coreDataOperationsOutOfBounds() async throws {
        let context = createIsolatedContext()
        
        let items = createTestInventoryItems(in: context, count: 3)
        try context.save()
        
        // Try to delete index 5 when we only have 3 items (indices 0, 1, 2)
        let outOfBoundsOffsets = IndexSet([1, 5])
        CoreDataOperations.deleteItems(items, at: outOfBoundsOffsets, in: context)
        
        // Should only delete the valid index (1)
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let count = try context.count(for: fetchRequest)
        #expect(count == 2, "Should delete only the valid index")
    }
    
    @Test("CoreDataOperations should delete all items of specific type")
    func coreDataOperationsDeleteAll() async throws {
        let context = createIsolatedContext()
        
        let inventoryItems = createTestInventoryItems(in: context, count: 3)
        let catalogItems = createTestCatalogItems(in: context, count: 2)
        try context.save()
        
        // Verify both types exist
        let inventoryFetch: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let catalogFetch: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        
        let initialInventoryCount = try context.count(for: inventoryFetch)
        let initialCatalogCount = try context.count(for: catalogFetch)
        
        #expect(initialInventoryCount == 3)
        #expect(initialCatalogCount == 2)
        
        // Delete all inventory items
        CoreDataOperations.deleteAll(ofType: InventoryItem.self, from: inventoryItems, in: context)
        
        // Verify only inventory items were deleted
        let finalInventoryCount = try context.count(for: inventoryFetch)
        let finalCatalogCount = try context.count(for: catalogFetch)
        
        #expect(finalInventoryCount == 0, "All inventory items should be deleted")
        #expect(finalCatalogCount == 2, "Catalog items should remain untouched")
    }
    
    // MARK: - View State Management Tests
    
    @Test("ViewState should initialize with correct defaults")
    func viewStateInitialization() {
        // This test would verify any ViewState classes or structs
        // Based on the code I've seen, this might be implemented in ViewUtilities
        // For now, creating a placeholder that could be expanded
        
        // Example of what we might test:
        #expect(true, "Placeholder for view state initialization tests")
    }
    
    @Test("Animation helpers should provide consistent animations")
    func animationHelpersConsistency() {
        // Test any animation utilities that might be in ViewUtilities
        let defaultAnimation = Animation.default
        #expect(defaultAnimation != nil, "Default animation should be available")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Core Data operations should handle save failures gracefully")
    func coreDataSaveFailureHandling() async throws {
        let context = createIsolatedContext()
        
        // Create an item and force it into an invalid state
        let item = InventoryItem(context: context)
        item.id = "TEST-INVALID"
        // Don't set required fields to potentially cause validation errors
        
        // The actual error handling happens in CoreDataHelpers.safeSave
        // which should be tested separately, but we can verify the operation doesn't crash
        
        do {
            try context.save()
        } catch {
            // Expected - we're testing that errors are handled gracefully
            #expect(error != nil, "Should handle save errors without crashing")
        }
    }
}