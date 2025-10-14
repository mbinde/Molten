//
//  DebugCompilation.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import CoreData

/// Test file to isolate compilation issues
class DebugCompilation {
    
    func testBasicNSFetchRequest() {
        // Test 1: Basic NSFetchRequest with explicit generic parameter
        let fetchRequest1 = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        print("Test 1 passed: \(fetchRequest1)")
        
        // Test 2: NSFetchRequest for dictionary results
        let fetchRequest2 = NSFetchRequest<NSDictionary>(entityName: "Inventory")
        fetchRequest2.propertiesToFetch = ["type"]
        fetchRequest2.returnsDistinctResults = true
        fetchRequest2.resultType = .dictionaryResultType
        print("Test 2 passed: \(fetchRequest2)")
    }
    
    func testCoreDataInventoryRepository() {
        // Test if we can reference the repository class
        let container = NSPersistentContainer(name: "TestModel")
        let repo = CoreDataInventoryRepository(persistentContainer: container)
        print("CoreDataInventoryRepository compiles: \(repo)")
    }
}