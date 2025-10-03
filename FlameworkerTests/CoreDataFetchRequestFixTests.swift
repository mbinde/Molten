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
    
    @Test("Entity classes are available and correctly typed")
    func entityClassesAvailability() {
        // Test that the Core Data entity classes exist and have the expected type
        // This will fail at compile time if the classes don't exist
        
        // Verify class types exist
        let catalogType = CatalogItem.self
        let inventoryType = InventoryItem.self
        
        #expect(catalogType is NSManagedObject.Type, "CatalogItem should be an NSManagedObject subclass")
        #expect(inventoryType is NSManagedObject.Type, "InventoryItem should be an NSManagedObject subclass")
        
        // Verify fetch request methods are available
        let catalogFetchRequest = CatalogItem.fetchRequest()
        let inventoryFetchRequest = InventoryItem.fetchRequest()
        
        #expect(catalogFetchRequest.entityName == "CatalogItem", "CatalogItem fetchRequest should have correct entity name")
        #expect(inventoryFetchRequest.entityName == "InventoryItem", "InventoryItem fetchRequest should have correct entity name")
    }
}