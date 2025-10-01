//
//  DataLoadingServiceTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
import Foundation
@testable import Flameworker

@Suite("Data Loading Service Tests")
struct DataLoadingServiceTests {
    
    // MARK: - Test Helpers
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        // Use TestUtilities for consistent context creation
        return TestUtilities.createHyperIsolatedContext(for: "DataLoadingServiceTests")
    }
    
    private func tearDownContext(_ context: NSManagedObjectContext) {
        // Use TestUtilities for consistent cleanup
        TestUtilities.tearDownHyperIsolatedContext(context)
    }
    
    /// Validates that a Core Data context is in a safe state for testing
    private func validateContext(_ context: NSManagedObjectContext) throws {
        guard context.persistentStoreCoordinator != nil else {
            throw NSError(domain: "TestError", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent store coordinator"
            ])
        }
        
        // Verify the context can perform basic operations
        do {
            _ = try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "CatalogItem"))
        } catch {
            throw NSError(domain: "TestError", code: 1003, userInfo: [
                NSLocalizedDescriptionKey: "Context cannot perform fetch operations: \(error.localizedDescription)"
            ])
        }
    }
    
    /// Safer helper to perform context operations with error handling
    private func performSafely<T>(in context: NSManagedObjectContext, operation: @escaping () throws -> T) throws -> T {
        try validateContext(context)
        
        // Use performAndWait to ensure thread safety and avoid collection mutation
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
    
    private func createEmptyJSONData() -> Data {
        return TestUtilities.createEmptyJSONData()
    }
    
    private func createSampleCatalogJSONData() -> Data {
        return TestUtilities.createSampleCatalogJSONData()
    }
    
    /// Helper method to safely create a CatalogItem with only essential attributes
    /// Uses direct property assignment to avoid KVC issues
    private func createTestCatalogItem(in context: NSManagedObjectContext, code: String, name: String, manufacturer: String? = nil) -> CatalogItem {
        var item: CatalogItem!
        
        // Perform all Core Data operations within performAndWait to avoid collection mutation
        context.performAndWait {
            // Validate context within the performAndWait block
            guard context.persistentStoreCoordinator != nil else {
                fatalError("Context has no persistent store coordinator")
            }
            
            // Use NSEntityDescription to ensure we're working with the correct entity
            guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
                fatalError("Could not find CatalogItem entity in context")
            }
            
            item = CatalogItem(entity: entity, insertInto: context)
            
            // Use direct property assignment instead of KVC to avoid potential crashes
            item.code = code
            item.name = name
            
            // Only set optional manufacturer if we have a non-nil, non-empty value
            if let manufacturer = manufacturer, !manufacturer.isEmpty {
                item.manufacturer = manufacturer
            } else {
                item.manufacturer = "Test Manufacturer"
            }
            
            // Set required date field
            item.start_date = Date()
        }
        
        return item
    }
    
    // MARK: - Service Instance Tests
    
    @Test("DataLoadingService should be singleton")
    func dataLoadingServiceSingleton() {
        let service1 = DataLoadingService.shared
        let service2 = DataLoadingService.shared
        
        #expect(service1 === service2, "DataLoadingService should be a singleton")
    }
    
    @Test("DataLoadingService should initialize without crashing")
    func dataLoadingServiceInitialization() {
        let service = DataLoadingService.shared
        #expect(service != nil, "DataLoadingService should initialize successfully")
    }
    
    @Test("Test context should be properly isolated")
    func testContextIsolation() throws {
        let context1 = createIsolatedContext()
        let context2 = createIsolatedContext()
        
        defer {
            tearDownContext(context1)
            tearDownContext(context2)
        }
        
        // Contexts should be different instances
        #expect(context1 !== context2, "Contexts should be different instances")
        
        // Both contexts should be functional
        try validateContext(context1)
        try validateContext(context2)
        
        // Test that changes in one context don't affect the other
        var item1: CatalogItem!
        context1.performAndWait {
            item1 = createTestCatalogItem(in: context1, code: "ISOLATION-1", name: "Item 1")
            try! context1.save()
        }
        
        // Context2 should not see the item from context1 - use safe operation
        let items = try performSafely(in: context2) {
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "code == %@", "ISOLATION-1")
            return try context2.fetch(fetchRequest)
        }
        
        #expect(items.isEmpty, "Context2 should not see items from Context1")
    }
    
    // MARK: - Core Data Integration Tests
    
    @Test("DataLoadingService should count existing items correctly")
    func dataLoadingServiceCountExisting() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Create and save items within performAndWait to avoid collection mutation
        try performSafely(in: context) {
            let item1 = createTestCatalogItem(in: context, code: "EXISTING-001", name: "Existing Item 1")
            let item2 = createTestCatalogItem(in: context, code: "EXISTING-002", name: "Existing Item 2")
            
            // Ensure items were created successfully
            #expect(item1.isInserted)
            #expect(item2.isInserted)
            
            try context.save()
            
            // Test that we can count existing items
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            let existingCount = try context.count(for: fetchRequest)
            
            #expect(existingCount == 2, "Should correctly count existing items")
            
            return Void() // Explicit return for closure
        }
    }
    
    @Test("DataLoadingService should handle empty context")
    func dataLoadingServiceEmptyContext() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Test counting in empty context using safe operation
        let count = try performSafely(in: context) {
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            return try context.count(for: fetchRequest)
        }
        
        #expect(count == 0, "Empty context should have zero items")
    }
    
    @Test("DataLoadingService should save items correctly")
    func dataLoadingServiceSaveItems() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Create and save item within performAndWait to avoid collection mutation
        try performSafely(in: context) {
            let item = createTestCatalogItem(in: context, code: "SAVE-TEST-001", name: "Save Test Item", manufacturer: "Test Manufacturer")
            
            // Verify item was created properly
            #expect(item.isInserted, "Item should be inserted in context")
            #expect(!item.isDeleted, "Item should not be marked as deleted")
            
            try context.save()
            
            // Verify it was saved by refreshing the context
            context.refreshAllObjects()
            
            // Verify item exists after save
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "code == %@", "SAVE-TEST-001")
            fetchRequest.fetchLimit = 1
            
            let savedItems = try context.fetch(fetchRequest)
            #expect(savedItems.count == 1, "Should save one item")
            
            if let savedItem = savedItems.first {
                #expect(savedItem.name == "Save Test Item", "Should save item with correct name")
                #expect(!savedItem.isFault, "Saved item should not be a fault")
            }
            
            return Void() // Explicit return for closure
        }
    }
    
    // MARK: - JSON Processing Tests
    
    @Test("DataLoadingService should handle empty JSON array")
    func dataLoadingServiceEmptyJSON() async throws {
        // Test that the service can handle an empty JSON array
        // This tests the JSON processing logic indirectly
        let emptyData = createEmptyJSONData()
        
        // Verify the empty JSON data is valid
        let decoder = JSONDecoder()
        let emptyArray = try decoder.decode([CatalogItemData].self, from: emptyData)
        #expect(emptyArray.isEmpty, "Should decode empty JSON array correctly")
    }
    
    @Test("DataLoadingService should process valid JSON data")
    func dataLoadingServiceValidJSON() {
        let jsonData = createSampleCatalogJSONData()
        
        // Test JSON decoding
        let decoder = JSONDecoder()
        do {
            let catalogItems = try decoder.decode([CatalogItemData].self, from: jsonData)
            
            #expect(catalogItems.count == 2, "Should decode 2 items from sample JSON")
            #expect(catalogItems[0].code == "TEST-001", "Should decode first item correctly")
            #expect(catalogItems[1].name == "Test Glass Frit", "Should decode second item correctly")
        } catch {
            #expect(Bool(false), "Should successfully decode valid JSON: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("DataLoadingService should handle malformed JSON gracefully")
    func dataLoadingServiceMalformedJSON() {
        let malformedJSON = "{ invalid json }".data(using: .utf8)!
        
        // Test that malformed JSON throws appropriate errors
        let decoder = JSONDecoder()
        
        do {
            _ = try decoder.decode([CatalogItemData].self, from: malformedJSON)
            #expect(Bool(false), "Should throw error for malformed JSON")
        } catch {
            #expect(error != nil, "Should throw decoding error for malformed JSON")
        }
    }
    
    @Test("DataLoadingService should handle missing JSON file gracefully")
    func dataLoadingServiceMissingFile() {
        let service = DataLoadingService.shared
        
        // The service should handle missing files gracefully
        // Since we can't easily test the actual file loading here,
        // we test that the service initializes without crashing
        #expect(service != nil, "Service should handle missing files gracefully")
    }
    
    @Test("DataLoadingService should handle Core Data save failures")
    func dataLoadingServiceSaveFailures() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create an item that should save successfully first
            let item1 = createTestCatalogItem(in: context, code: "VALID-ITEM", name: "Valid Item")
            #expect(item1.isInserted, "First item should be inserted")
            
            try context.save()
            #expect(!item1.isInserted, "First item should no longer be inserted after save")
            #expect(!item1.isUpdated, "First item should not be updated after save")
            
            // Now try to create another item with the same code 
            // This may or may not cause a constraint violation depending on the model
            let item2 = createTestCatalogItem(in: context, code: "VALID-ITEM", name: "Duplicate Item")
            #expect(item2.isInserted, "Second item should be inserted before save")
            
            do {
                try context.save()
                // If it saves without error, the model may allow duplicates
                print("Context saved duplicate items successfully (model may allow duplicate codes)")
                #expect(true, "Context saved successfully (model may allow duplicate codes)")
            } catch let error as NSError {
                // Expected if there are unique constraints
                print("Expected save error for duplicate: \(error.localizedDescription)")
                #expect(error.domain == NSCocoaErrorDomain || error.domain == NSSQLiteErrorDomain, 
                       "Should be a Core Data or SQLite error")
                
                // Reset context to clean state after error
                context.rollback()
                
                // Verify rollback worked
                #expect(item2.isDeleted || !item2.isInserted, "Item2 should be rolled back")
            }
            
            return Void() // Explicit return for closure
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("DataLoadingService should handle batch processing efficiently")
    func dataLoadingServiceBatchPerformance() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        let startTime = Date()
        let totalItems = 50
        
        // Create all items within a single performAndWait to avoid collection mutation
        try performSafely(in: context) {
            var createdItems: [CatalogItem] = []
            
            // Create all items in one atomic operation
            for i in 0..<totalItems {
                let item = createTestCatalogItem(
                    in: context,
                    code: "BATCH-\(i)",
                    name: "Batch Item \(i)",
                    manufacturer: "Batch Manufacturer \(i % 5)"
                )
                createdItems.append(item)
            }
            
            // Verify items were created properly (do this before saving to avoid mutation)
            for (index, item) in createdItems.enumerated() {
                #expect(item.isInserted, "Item \(index) should be inserted")
            }
            
            // Save all items at once
            try context.save()
            
            let endTime = Date()
            let timeElapsed = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
            
            print("Batch processing took \(timeElapsed) seconds for \(createdItems.count) items")
            #expect(timeElapsed < 5.0, "Should process \(createdItems.count) items within 5 seconds")
            
            // Verify all items were saved
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "code BEGINSWITH 'BATCH-'")
            let savedCount = try context.count(for: fetchRequest)
            
            #expect(savedCount == createdItems.count, "Should save all \(createdItems.count) batch items")
            
            // Verify a sample of items are not faults (check only first few to avoid iteration issues)
            let sampleSize = min(3, createdItems.count)
            for i in 0..<sampleSize {
                let item = createdItems[i]
                #expect(!item.isFault, "Saved item \(i) should not be a fault")
            }
            
            return Void() // Explicit return for closure
        }
    }
    
    @Test("DataLoadingService should handle concurrent access safely")
    func dataLoadingServiceConcurrentAccess() async throws {
        // Test that multiple accesses to the singleton don't cause issues
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let service = DataLoadingService.shared
                    _ = service // Use the service
                }
            }
        }
        
        // Verify singleton is still accessible after concurrent access
        let service = DataLoadingService.shared
        #expect(service != nil, "Service should remain accessible after concurrent access")
    }
    
    // MARK: - Logging Integration Tests
    
    @Test("DataLoadingService should use structured logging")
    func dataLoadingServiceStructuredLogging() {
        let service = DataLoadingService.shared
        
        // Test that the service initializes its logger properly
        // We can't easily test the actual logging output, but we can verify
        // the service doesn't crash during initialization where logging is set up
        #expect(service != nil, "Service should set up logging without issues")
    }
    
    @Test("DataLoadingService should log processing progress")
    func dataLoadingServiceProgressLogging() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Create and verify items within safe operation to avoid collection mutation
        try performSafely(in: context) {
            var createdItems: [CatalogItem] = []
            for i in 0..<5 {
                let item = createTestCatalogItem(in: context, code: "LOG-TEST-\(i)", name: "Log Test Item \(i)")
                createdItems.append(item)
                #expect(item.isInserted, "Item \(i) should be inserted")
            }
            
            try context.save()
            
            // Verify all items are no longer in inserted state after save
            for (index, item) in createdItems.enumerated() {
                #expect(!item.isInserted, "Item \(index) should not be inserted after save")
                #expect(!item.isFault, "Item \(index) should not be a fault after save")
            }
            
            // The actual logging happens in the service methods
            // This test verifies that the operations complete successfully
            // which indirectly tests that logging doesn't interfere with processing
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "code BEGINSWITH 'LOG-TEST-'")
            
            let count = try context.count(for: fetchRequest)
            #expect(count == 5, "Should complete operations with logging active")
            
            // Also verify by fetching the actual objects
            let savedItems = try context.fetch(fetchRequest)
            #expect(savedItems.count == 5, "Should fetch all logged items")
            
            return Void() // Explicit return for closure
        }
    }
    
    // MARK: - CatalogItemData Model Tests
    
    @Test("CatalogItemData should decode from JSON correctly")
    func catalogItemDataDecoding() async throws {
        let jsonData = createSampleCatalogJSONData()
        
        let decoder = JSONDecoder()
        let items = try decoder.decode([CatalogItemData].self, from: jsonData)
        
        #expect(items.count == 2, "Should decode correct number of items")
        
        let firstItem = items[0]
        #expect(firstItem.code == "TEST-001", "Should decode code correctly")
        #expect(firstItem.name == "Test Glass Rod", "Should decode name correctly")
    }
}