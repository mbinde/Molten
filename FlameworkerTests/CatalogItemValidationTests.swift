//
//  CatalogItemValidationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 9/30/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("CatalogItem Validation Tests")
struct CatalogItemValidationTests {
    
    // MARK: - Test Helpers
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        return TestUtilities.createHyperIsolatedContext(for: "CatalogItemValidationTests")
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
    
    /// Creates a sample CatalogItem for testing - uses same pattern as Persistence.swift
    private func createSampleCatalogItem(in context: NSManagedObjectContext) -> CatalogItem {
        let item = CatalogItem(context: context)
        item.code = "CATALOG-001"
        item.name = "Test Glass Rod"
        item.manufacturer = "Test Manufacturer"
        return item
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("CatalogItem basic creation and property access")
    func catalogItemBasicCreation() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Test basic item creation using the same pattern as Persistence.swift
            let item = CatalogItem(context: context)
            item.code = "TEST-001"
            item.name = "Test Item"
            item.manufacturer = "Test Manufacturer"
            
            // Test that the properties are set correctly
            #expect(item.code == "TEST-001", "Code should be set correctly")
            #expect(item.name == "Test Item", "Name should be set correctly")
            #expect(item.manufacturer == "Test Manufacturer", "Manufacturer should be set correctly")
            
            // Test save operation
            try context.save()
            
            // Test fetch operation
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "code == %@", "TEST-001")
            let results = try context.fetch(fetchRequest)
            
            #expect(results.count == 1, "Should find exactly one item")
            #expect(results.first?.code == "TEST-001", "Fetched item should have correct code")
            #expect(results.first?.name == "Test Item", "Fetched item should have correct name")
            
            return Void()
        }
    }
}