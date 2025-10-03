//
//  CoreDataFetchRequestFixTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data FetchRequest Fix Tests")
struct CoreDataFetchRequestFixTests {
    
    @Test("FetchRequest creation with entity works correctly")
    func fetchRequestCreationWithEntity() {
        // Test that we can create fetch requests with entities without crashing
        
        // Test CatalogItem fetch request
        let catalogFetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        catalogFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
        
        #expect(catalogFetchRequest.entityName == "CatalogItem", "Should have correct entity name")
        #expect(catalogFetchRequest.sortDescriptors?.count == 1, "Should have sort descriptors")
        
        // Test InventoryItem fetch request
        let inventoryFetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
        inventoryFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.type, ascending: true)]
        
        #expect(inventoryFetchRequest.entityName == "InventoryItem", "Should have correct entity name")
        #expect(inventoryFetchRequest.sortDescriptors?.count == 1, "Should have sort descriptors")
    }
    
    @Test("FetchRequest with predicate creation works")
    func fetchRequestWithPredicateCreation() {
        // Test creating fetch request with compound predicate (like RelatedInventoryItemsView)
        let catalogCode = "TEST123"
        let manufacturer = "TestMfg"
        
        var predicates: [NSPredicate] = []
        
        // Search for exact match
        predicates.append(NSPredicate(format: "catalog_code == %@", catalogCode))
        
        // Search for manufacturer-code format
        let prefixedCode = "\(manufacturer)-\(catalogCode)"
        predicates.append(NSPredicate(format: "catalog_code == %@", prefixedCode))
        
        // Search for codes ending with catalog code
        predicates.append(NSPredicate(format: "catalog_code ENDSWITH %@", "-\(catalogCode)"))
        
        // Combine all predicates with OR
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
        fetchRequest.predicate = compoundPredicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.type, ascending: true)]
        
        #expect(fetchRequest.entityName == "InventoryItem", "Should have correct entity name")
        #expect(fetchRequest.predicate != nil, "Should have predicate")
        #expect(fetchRequest.sortDescriptors?.count == 1, "Should have sort descriptors")
    }
    
    @Test("Entity access methods work correctly")
    func entityAccessMethods() {
        // Test that entity() methods are available and return proper entities
        // Note: This tests the API without requiring a full Core Data stack
        
        // These calls should not crash
        let catalogEntity = CatalogItem.entity()
        let inventoryEntity = InventoryItem.entity()
        
        #expect(catalogEntity.name == "CatalogItem", "CatalogItem entity should have correct name")
        #expect(inventoryEntity.name == "InventoryItem", "InventoryItem entity should have correct name")
    }
}