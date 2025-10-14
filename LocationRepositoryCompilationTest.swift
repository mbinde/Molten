//
//  LocationRepositoryCompilationTest.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import CoreData

/// Test file to isolate compilation issues in CoreDataLocationRepository
class LocationRepositoryCompilationTest {
    
    func testBasicCompilation() {
        // Test 1: Basic NSFetchRequest creation
        let fetchRequest1 = NSFetchRequest<NSManagedObject>(entityName: "Location")
        print("Basic fetch request works: \(fetchRequest1)")
        
        // Test 2: Dictionary fetch request  
        let fetchRequest2 = NSFetchRequest<NSDictionary>(entityName: "Location")
        fetchRequest2.propertiesToFetch = ["location"]
        fetchRequest2.returnsDistinctResults = true
        fetchRequest2.resultType = .dictionaryResultType
        print("Dictionary fetch request works: \(fetchRequest2)")
    }
    
    func testRepositoryCreation() {
        // Test creating the repository with explicit container
        let container = NSPersistentContainer(name: "TestModel")
        let repo = CoreDataLocationRepository(locationPersistentContainer: container)
        print("CoreDataLocationRepository compiles: \(repo)")
    }
    
    func testLocationModelCreation() {
        // Test creating LocationModel
        let location = LocationModel(
            inventoryId: UUID(),
            location: "Test Location", 
            quantity: 5.0
        )
        print("LocationModel works: \(location)")
    }
}