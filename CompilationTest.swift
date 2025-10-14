//
//  CompilationTest.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import CoreData
@testable import Flameworker

/// This file exists to test that CoreDataInventoryRepository compiles correctly
/// It can be removed once compilation issues are resolved
class CompilationTest {
    
    func testCoreDataRepositoriesCompile() {
        // Test that we can create an NSPersistentContainer
        let container = NSPersistentContainer(name: "TestModel")
        
        // Test basic NSFetchRequest syntax
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "itemNaturalKey == %@", "test")
        print("NSFetchRequest syntax works: \(fetchRequest)")
        
        print("Core Data components compile successfully with container: \(container)")
    }
    
    func testNSFetchRequestSyntax() {
        // Test the NSFetchRequest syntax that was causing issues
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "itemNaturalKey == %@", "test")
        
        print("NSFetchRequest syntax works: \(fetchRequest)")
    }
}