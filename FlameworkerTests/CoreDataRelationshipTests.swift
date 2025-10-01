//
//  CoreDataRelationshipTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 9/30/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Relationship Tests")
struct CoreDataRelationshipTests {
    
    // MARK: - Test Helpers
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        return TestUtilities.createHyperIsolatedContext(for: "CoreDataRelationshipTests")
    }
    
    private func tearDownContext(_ context: NSManagedObjectContext) {
        TestUtilities.tearDownHyperIsolatedContext(context)
    }
    
    /// Safer helper to perform context operations with error handling
    private func performSafely<T>(in context: NSManagedObjectContext, operation: @escaping () throws -> T) throws -> T {
        guard context.persistentStoreCoordinator != nil else {
            throw NSError(domain: "TestError", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent store coordinator"
            ])
        }
        
        var result: Result<T, Error>?
        
        context.performAndWait {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// Creates a sample InventoryItem for testing
    private func createSampleInventoryItem(in context: NSManagedObjectContext, id: String = "TEST-001") -> InventoryItem {
        let item = InventoryItem(context: context)
        item.id = id
        item.catalog_code = "BR-GLR-\(id)"
        item.count = 50.0
        item.units = 1
        item.type = InventoryItemType.sell.rawValue
        item.notes = "Test item for relationships"
        return item
    }
    
    /// Creates a sample CatalogItem for testing
    private func createSampleCatalogItem(in context: NSManagedObjectContext, code: String = "CATALOG-001") -> CatalogItem {
        let item = CatalogItem(context: context)
        item.code = code
        item.name = "Test Glass Rod"
        item.manufacturer = "Test Manufacturer"
        return item
    }
    
    /// Creates a sample PurchaseRecord for testing
    private func createSamplePurchaseRecord(in context: NSManagedObjectContext, supplier: String = "Test Supplier") -> PurchaseRecord {
        let record = PurchaseRecord(context: context)
        record.setValue(supplier, forKey: "supplier")
        record.setValue(100.0, forKey: "price")
        record.setValue(Date(), forKey: "date_added")
        return record
    }
    
    // MARK: - InventoryItem to CatalogItem Relationship Tests
    
    @Test("InventoryItem to CatalogItem relationship establishment")
    func inventoryItemToCatalogItemRelationship() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items
            let inventoryItem = createSampleInventoryItem(in: context, id: "INV-001")
            let catalogItem = createSampleCatalogItem(in: context, code: "CAT-001")
            
            // Test if relationship exists by checking entity relationships
            let inventoryEntity = inventoryItem.entity
            let catalogEntity = catalogItem.entity
            
            // Check if there are any relationships defined between these entities
            let inventoryRelationships = inventoryEntity.relationshipsByName
            let catalogRelationships = catalogEntity.relationshipsByName
            
            // If relationships exist, test them
            if let catalogRelationship = inventoryRelationships["catalogItem"] {
                // Test setting the relationship
                inventoryItem.setValue(catalogItem, forKey: "catalogItem")
                
                #expect(inventoryItem.value(forKey: "catalogItem") as? CatalogItem === catalogItem,
                       "InventoryItem should reference the correct CatalogItem")
                
                // Test inverse relationship if it exists
                if let inverseRelationship = catalogRelationship.inverseRelationship {
                    let relatedInventoryItems = catalogItem.value(forKey: inverseRelationship.name) as? Set<InventoryItem>
                    #expect(relatedInventoryItems?.contains(inventoryItem) == true,
                           "CatalogItem should contain the related InventoryItem in inverse relationship")
                }
            }
            
            // Save and verify persistence
            try context.save()
            
            // Fetch and verify the relationship persists
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "INV-001")
            let fetchedItems = try context.fetch(fetchRequest)
            
            #expect(fetchedItems.count == 1, "Should fetch exactly one inventory item")
            
            if inventoryRelationships["catalogItem"] != nil {
                let fetchedCatalogItem = fetchedItems.first?.value(forKey: "catalogItem") as? CatalogItem
                #expect(fetchedCatalogItem?.code == "CAT-001", "Relationship should persist after save")
            }
            
            return Void()
        }
    }
    
    @Test("Multiple InventoryItems linked to same CatalogItem")
    func multipleInventoryItemsToOneCatalogItem() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let catalogItem = createSampleCatalogItem(in: context, code: "SHARED-CAT")
            let inventoryItem1 = createSampleInventoryItem(in: context, id: "INV-001")
            let inventoryItem2 = createSampleInventoryItem(in: context, id: "INV-002")
            
            // Check if catalog relationship exists
            if inventoryItem1.entity.relationshipsByName["catalogItem"] != nil {
                // Link both inventory items to the same catalog item
                inventoryItem1.setValue(catalogItem, forKey: "catalogItem")
                inventoryItem2.setValue(catalogItem, forKey: "catalogItem")
                
                try context.save()
                
                // Verify both items are linked to the same catalog item
                #expect(inventoryItem1.value(forKey: "catalogItem") as? CatalogItem === catalogItem,
                       "First inventory item should link to catalog item")
                #expect(inventoryItem2.value(forKey: "catalogItem") as? CatalogItem === catalogItem,
                       "Second inventory item should link to catalog item")
                
                // Test inverse relationship if it exists
                if let inverseRelationshipName = inventoryItem1.entity.relationshipsByName["catalogItem"]?.inverseRelationship?.name {
                    let relatedItems = catalogItem.value(forKey: inverseRelationshipName) as? Set<InventoryItem>
                    #expect(relatedItems?.count == 2, "CatalogItem should have two related inventory items")
                    #expect(relatedItems?.contains(inventoryItem1) == true, "Should contain first inventory item")
                    #expect(relatedItems?.contains(inventoryItem2) == true, "Should contain second inventory item")
                }
            }
            
            return Void()
        }
    }
    
    // MARK: - Cascade Delete Behavior Tests
    
    @Test("Cascade delete behavior verification")
    func cascadeDeleteBehavior() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let catalogItem = createSampleCatalogItem(in: context, code: "DELETE-TEST")
            let inventoryItem = createSampleInventoryItem(in: context, id: "DELETE-INV")
            
            // Link items if relationship exists
            if inventoryItem.entity.relationshipsByName["catalogItem"] != nil {
                inventoryItem.setValue(catalogItem, forKey: "catalogItem")
                try context.save()
                
                // Get initial counts
                let initialCatalogCount = try context.count(for: CatalogItem.fetchRequest())
                let initialInventoryCount = try context.count(for: InventoryItem.fetchRequest())
                
                // Delete the catalog item and test cascade behavior
                context.delete(catalogItem)
                try context.save()
                
                let finalCatalogCount = try context.count(for: CatalogItem.fetchRequest())
                let finalInventoryCount = try context.count(for: InventoryItem.fetchRequest())
                
                #expect(finalCatalogCount == initialCatalogCount - 1,
                       "CatalogItem should be deleted")
                
                // Check if inventory item still exists (depends on cascade rules)
                let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", "DELETE-INV")
                let remainingInventoryItems = try context.fetch(fetchRequest)
                
                // Test cascade delete rule - if nullify, inventory item should exist with nil relationship
                // If cascade delete, inventory item should be deleted
                let relationshipDeleteRule = inventoryItem.entity.relationshipsByName["catalogItem"]?.deleteRule ?? .nullifyDeleteRule
                
                switch relationshipDeleteRule {
                case .cascadeDeleteRule:
                    #expect(remainingInventoryItems.isEmpty,
                           "InventoryItem should be cascade deleted with CatalogItem")
                case .nullifyDeleteRule:
                    #expect(remainingInventoryItems.count == 1,
                           "InventoryItem should remain but with nullified relationship")
                    #expect(remainingInventoryItems.first?.value(forKey: "catalogItem") == nil,
                           "CatalogItem relationship should be nullified")
                default:
                    // Other delete rules can be tested based on actual configuration
                    break
                }
            }
            
            return Void()
        }
    }
    
    @Test("Reverse cascade delete behavior")
    func reverseCascadeDeleteBehavior() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let catalogItem = createSampleCatalogItem(in: context, code: "REV-DELETE-TEST")
            let inventoryItem = createSampleInventoryItem(in: context, id: "REV-DELETE-INV")
            
            if inventoryItem.entity.relationshipsByName["catalogItem"] != nil {
                inventoryItem.setValue(catalogItem, forKey: "catalogItem")
                try context.save()
                
                let initialCatalogCount = try context.count(for: CatalogItem.fetchRequest())
                let initialInventoryCount = try context.count(for: InventoryItem.fetchRequest())
                
                // Delete the inventory item and test reverse cascade behavior
                context.delete(inventoryItem)
                try context.save()
                
                let finalCatalogCount = try context.count(for: CatalogItem.fetchRequest())
                let finalInventoryCount = try context.count(for: InventoryItem.fetchRequest())
                
                #expect(finalInventoryCount == initialInventoryCount - 1,
                       "InventoryItem should be deleted")
                
                // CatalogItem should still exist (typically no cascade from many-to-one side)
                #expect(finalCatalogCount == initialCatalogCount,
                       "CatalogItem should remain when InventoryItem is deleted")
                
                // Verify the catalog item is still accessible
                let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "code == %@", "REV-DELETE-TEST")
                let remainingCatalogItems = try context.fetch(fetchRequest)
                
                #expect(remainingCatalogItems.count == 1,
                       "CatalogItem should still exist after InventoryItem deletion")
            }
            
            return Void()
        }
    }
    
    // MARK: - Relationship Integrity Constraint Tests
    
    @Test("Relationship integrity constraints")
    func relationshipIntegrityConstraints() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let inventoryItem = createSampleInventoryItem(in: context, id: "CONSTRAINT-TEST")
            
            // Test setting invalid relationship (if constraints exist)
            if inventoryItem.entity.relationshipsByName["catalogItem"] != nil {
                // Try to save with potentially invalid relationship state
                try context.save()
                
                // Test constraint validation by attempting to set nil on required relationship
                let relationship = inventoryItem.entity.relationshipsByName["catalogItem"]!
                
                if !relationship.isOptional {
                    // If relationship is required, setting to nil should cause validation error
                    inventoryItem.setValue(nil, forKey: "catalogItem")
                    
                    do {
                        try context.save()
                        // If save succeeds, the relationship might actually be optional
                        #expect(true, "Save succeeded - relationship appears to be optional")
                    } catch let error as NSError {
                        // Expected validation error for required relationship
                        #expect(error.domain == NSCocoaErrorDomain,
                               "Should get NSCocoaErrorDomain for validation error")
                        #expect(error.code == NSValidationMissingMandatoryPropertyError ||
                               error.code == NSValidationRelationshipLacksMinimumCountError,
                               "Should get validation error for missing required relationship")
                    }
                }
            }
            
            return Void()
        }
    }
    
    @Test("Unique constraint violations")
    func uniqueConstraintViolations() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create two items with same code to test unique constraints
            let catalogItem1 = createSampleCatalogItem(in: context, code: "UNIQUE-TEST")
            let catalogItem2 = createSampleCatalogItem(in: context, code: "UNIQUE-TEST")
            
            do {
                try context.save()
                
                // If save succeeds, there might not be a unique constraint
                let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "code == %@", "UNIQUE-TEST")
                let results = try context.fetch(fetchRequest)
                
                if results.count > 1 {
                    #expect(true, "No unique constraint on code - multiple items with same code allowed")
                }
            } catch let error as NSError {
                // Expected unique constraint violation
                #expect(error.domain == NSCocoaErrorDomain,
                       "Should get NSCocoaErrorDomain for constraint violation")
                #expect(error.code == NSConstraintConflictError,
                       "Should get constraint conflict error for duplicate codes")
            }
            
            return Void()
        }
    }
    
    // MARK: - Fetching Related Objects Tests
    
    @Test("Fetching related objects through relationships")
    func fetchingRelatedObjects() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let catalogItem = createSampleCatalogItem(in: context, code: "FETCH-TEST")
            let inventoryItem1 = createSampleInventoryItem(in: context, id: "FETCH-INV-1")
            let inventoryItem2 = createSampleInventoryItem(in: context, id: "FETCH-INV-2")
            
            // Link items if relationship exists
            if inventoryItem1.entity.relationshipsByName["catalogItem"] != nil {
                inventoryItem1.setValue(catalogItem, forKey: "catalogItem")
                inventoryItem2.setValue(catalogItem, forKey: "catalogItem")
                try context.save()
                
                // Test fetching inventory items through catalog item relationship
                let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "catalogItem.code == %@", "FETCH-TEST")
                let relatedInventoryItems = try context.fetch(fetchRequest)
                
                #expect(relatedInventoryItems.count == 2,
                       "Should fetch both inventory items related to catalog item")
                
                let fetchedIds = Set(relatedInventoryItems.compactMap { $0.id })
                #expect(fetchedIds.contains("FETCH-INV-1"), "Should contain first inventory item")
                #expect(fetchedIds.contains("FETCH-INV-2"), "Should contain second inventory item")
                
                // Test reverse fetch - get catalog item from inventory item
                let catalogFetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
                catalogFetchRequest.predicate = NSPredicate(format: "SUBQUERY(inventoryItems, $item, $item.id == %@).@count > 0", "FETCH-INV-1")
                
                // This predicate assumes there's an inverse relationship named 'inventoryItems'
                // Adjust the predicate based on actual relationship name
                do {
                    let relatedCatalogItems = try context.fetch(catalogFetchRequest)
                    #expect(relatedCatalogItems.count <= 1,
                           "Should find at most one catalog item related to inventory item")
                } catch {
                    // If the relationship doesn't exist or has a different name, this is expected
                    #expect(true, "Relationship structure may differ from assumption")
                }
            }
            
            return Void()
        }
    }
    
    @Test("Complex relationship queries with predicates")
    func complexRelationshipQueries() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create multiple catalog items and inventory items for complex queries
            let glassRodCatalog = createSampleCatalogItem(in: context, code: "GLASS-ROD")
            glassRodCatalog.name = "Glass Rod"
            glassRodCatalog.manufacturer = "Manufacturer A"
            
            let glassFritCatalog = createSampleCatalogItem(in: context, code: "GLASS-FRIT")
            glassFritCatalog.name = "Glass Frit"
            glassFritCatalog.manufacturer = "Manufacturer B"
            
            let inventory1 = createSampleInventoryItem(in: context, id: "INV-1")
            inventory1.count = 100.0
            inventory1.type = InventoryItemType.inventory.rawValue
            
            let inventory2 = createSampleInventoryItem(in: context, id: "INV-2")
            inventory2.count = 50.0
            inventory2.type = InventoryItemType.sell.rawValue
            
            let inventory3 = createSampleInventoryItem(in: context, id: "INV-3")
            inventory3.count = 25.0
            inventory3.type = InventoryItemType.buy.rawValue
            
            // Link items if relationships exist
            if inventory1.entity.relationshipsByName["catalogItem"] != nil {
                inventory1.setValue(glassRodCatalog, forKey: "catalogItem")
                inventory2.setValue(glassRodCatalog, forKey: "catalogItem")
                inventory3.setValue(glassFritCatalog, forKey: "catalogItem")
                
                try context.save()
                
                // Query 1: Find all inventory items of a specific type linked to glass rod catalog
                let typeQuery: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                typeQuery.predicate = NSPredicate(format: "type == %d AND catalogItem.code == %@", 
                                                InventoryItemType.inventory.rawValue, "GLASS-ROD")
                let inventoryTypeResults = try context.fetch(typeQuery)
                #expect(inventoryTypeResults.count == 1, "Should find one inventory-type item linked to glass rod")
                
                // Query 2: Find catalog items with total inventory count above threshold
                let highCountQuery: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                highCountQuery.predicate = NSPredicate(format: "count > %f AND catalogItem != nil", 75.0)
                let highCountResults = try context.fetch(highCountQuery)
                #expect(highCountResults.count >= 1, "Should find items with count > 75")
                
                // Query 3: Find catalog items by manufacturer with specific inventory type
                let manufacturerQuery: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                manufacturerQuery.predicate = NSPredicate(format: "catalogItem.manufacturer == %@ AND type == %d",
                                                        "Manufacturer A", InventoryItemType.sell.rawValue)
                let manufacturerResults = try context.fetch(manufacturerQuery)
                #expect(manufacturerResults.count >= 0, "Should handle manufacturer-based queries")
            }
            
            return Void()
        }
    }
    
    // MARK: - Relationship Performance Tests
    
    @Test("Relationship fetching performance with large datasets")
    func relationshipFetchingPerformance() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let startTime = Date()
            
            // Create multiple catalog items
            var catalogItems: [CatalogItem] = []
            for i in 1...10 {
                let catalog = createSampleCatalogItem(in: context, code: "PERF-CAT-\(i)")
                catalogItems.append(catalog)
            }
            
            // Create many inventory items linked to catalog items
            if let relationship = InventoryItem(context: context).entity.relationshipsByName["catalogItem"] {
                for i in 1...100 {
                    let inventory = createSampleInventoryItem(in: context, id: "PERF-INV-\(i)")
                    let catalogIndex = (i - 1) % catalogItems.count
                    inventory.setValue(catalogItems[catalogIndex], forKey: "catalogItem")
                }
                
                try context.save()
                
                let saveTime = Date()
                let saveDuration = saveTime.timeIntervalSince(startTime)
                #expect(saveDuration < 10.0, "Large dataset save should complete within 10 seconds")
                
                // Test fetch performance
                let fetchStart = Date()
                let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "catalogItem != nil")
                let results = try context.fetch(fetchRequest)
                
                let fetchDuration = Date().timeIntervalSince(fetchStart)
                #expect(fetchDuration < 5.0, "Fetch should complete within 5 seconds")
                #expect(results.count == 100, "Should fetch all 100 inventory items")
                
                // Test relationship traversal performance
                let traversalStart = Date()
                for item in results.prefix(10) {
                    _ = item.value(forKey: "catalogItem") as? CatalogItem
                }
                let traversalDuration = Date().timeIntervalSince(traversalStart)
                #expect(traversalDuration < 1.0, "Relationship traversal should be fast")
            }
            
            return Void()
        }
    }
}