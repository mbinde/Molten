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
    
    @Test("NSFetchRequest creation with entity name works")
    func fetchRequestCreationWithEntityName() {
        // Test that we can create fetch requests with entity names without crashing
        // This doesn't require actual Core Data entities to exist
        
        let catalogFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogItem")
        #expect(catalogFetchRequest.entityName == "CatalogItem", "Should have correct entity name")
        
        let inventoryFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InventoryItem")
        #expect(inventoryFetchRequest.entityName == "InventoryItem", "Should have correct entity name")
    }
    
    @Test("NSPredicate creation works correctly")
    func predicateCreation() {
        // Test creating predicates that would be used with Core Data
        let catalogCode = "TEST123"
        let manufacturer = "TestMfg"
        
        // Test individual predicate creation
        let exactMatch = NSPredicate(format: "catalog_code == %@", catalogCode)
        #expect(exactMatch.predicateFormat.contains("catalog_code"), "Should contain catalog_code")
        #expect(exactMatch.predicateFormat.contains("TEST123"), "Should contain the test value")
        
        // Test compound predicate creation
        let prefixedCode = "\(manufacturer)-\(catalogCode)"
        let predicates = [
            NSPredicate(format: "catalog_code == %@", catalogCode),
            NSPredicate(format: "catalog_code == %@", prefixedCode),
            NSPredicate(format: "catalog_code ENDSWITH %@", "-\(catalogCode)")
        ]
        
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        #expect(compoundPredicate.subpredicates.count == 3, "Should have 3 subpredicates")
    }
    
    @Test("Sort descriptor creation works correctly")
    func sortDescriptorCreation() {
        // Test creating sort descriptors that would be used with Core Data
        let nameSort = NSSortDescriptor(key: "name", ascending: true)
        #expect(nameSort.key == "name", "Should have correct key")
        #expect(nameSort.ascending == true, "Should be ascending")
        
        let typeSort = NSSortDescriptor(key: "type", ascending: false)
        #expect(typeSort.key == "type", "Should have correct key")
        #expect(typeSort.ascending == false, "Should be descending")
        
        // Test multiple sort descriptors
        let multipleSorts = [nameSort, typeSort]
        #expect(multipleSorts.count == 2, "Should have 2 sort descriptors")
    }
    
    /*
    @Test("Core Data helpers work without context")
    func coreDataHelpersWithoutContext() {
        // Test CoreDataHelpers methods that don't require a managed object context
        
        // Test string array joining
        let tags = ["red", "glass", "rod"]
        let joinedTags = CoreDataHelpers.joinStringArray(tags)
        #expect(joinedTags == "red,glass,rod", "Should join array correctly")
        
        // Test empty array
        let emptyJoined = CoreDataHelpers.joinStringArray([])
        #expect(emptyJoined == "", "Should return empty string for empty array")
        
        // Test nil array
        let nilJoined = CoreDataHelpers.joinStringArray(nil)
        #expect(nilJoined == "", "Should return empty string for nil array")
    }
     */
}
