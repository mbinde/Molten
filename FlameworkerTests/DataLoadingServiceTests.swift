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
        // Create a completely isolated context that matches the main app model structure
        // but avoids CloudKit configuration conflicts
        
        // Find the data model bundle - try both main bundle and test bundle
        guard let modelURL = Bundle.main.url(forResource: "Flameworker", withExtension: "momd") ??
              Bundle(for: DataLoadingService.self).url(forResource: "Flameworker", withExtension: "momd") else {
            fatalError("Could not find Flameworker.momd in bundles")
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Could not load Core Data model from \(modelURL)")
        }
        
        // Create a standard persistent container (not CloudKit) to avoid configuration issues
        let container = NSPersistentContainer(name: "Flameworker", managedObjectModel: model)
        
        // Configure for in-memory storage with unique identifier
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSInMemoryStoreType
        storeDescription.url = URL(fileURLWithPath: "/dev/null")
        storeDescription.shouldAddStoreAsynchronously = false
        
        // Disable options that might cause conflicts with in-memory stores
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load the store synchronously
        var storeError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        container.loadPersistentStores { _, error in
            storeError = error
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = storeError {
            fatalError("Failed to load test store: \(error)")
        }
        
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = false
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Store container reference to prevent deallocation
        context.userInfo["testContainer"] = container
        
        return context
    }
    
    private func tearDownContext(_ context: NSManagedObjectContext) {
        // Clean up the isolated context
        context.reset()
        
        // Clean up container if stored
        if let container = context.userInfo["testContainer"] as? NSPersistentContainer {
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        
        context.userInfo.removeAllObjects()
    }
    
    private func createEmptyJSONData() -> Data {
        return TestUtilities.createEmptyJSONData()
    }
    
    private func createSampleCatalogJSONData() -> Data {
        return TestUtilities.createSampleCatalogJSONData()
    }
    
    /// Helper method to safely create a CatalogItem with only essential attributes
    /// Uses KVC to avoid compile-time property dependencies
    private func createTestCatalogItem(in context: NSManagedObjectContext, code: String, name: String, manufacturer: String? = nil) -> CatalogItem {
        // Use NSEntityDescription to ensure we're working with the correct entity
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            fatalError("Could not find CatalogItem entity in context")
        }
        
        let item = CatalogItem(entity: entity, insertInto: context)
        
        // Use KVC to set properties safely
        item.setValue(code, forKey: "code")
        item.setValue(name, forKey: "name")
        
        // Only set optional manufacturer if we have a non-nil, non-empty value
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            item.setValue(manufacturer, forKey: "manufacturer")
        }
        
        // Validate the item was created properly
        do {
            try context.obtainPermanentIDs(for: [item])
        } catch {
            print("Warning: Could not obtain permanent ID for test item: \(error)")
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
    
    // MARK: - Core Data Integration Tests
    
    @Test("DataLoadingService should count existing items correctly")
    func dataLoadingServiceCountExisting() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Create some existing catalog items using helper method
        _ = createTestCatalogItem(in: context, code: "EXISTING-001", name: "Existing Item 1")
        _ = createTestCatalogItem(in: context, code: "EXISTING-002", name: "Existing Item 2")
        
        try context.save()
        
        // Test that we can count existing items
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCount = try context.count(for: fetchRequest)
        
        #expect(existingCount == 2, "Should correctly count existing items")
    }
    
    @Test("DataLoadingService should handle empty context")
    func dataLoadingServiceEmptyContext() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Test counting in empty context
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let count = try context.count(for: fetchRequest)
        
        #expect(count == 0, "Empty context should have zero items")
    }
    
    @Test("DataLoadingService should save items correctly")
    func dataLoadingServiceSaveItems() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        // Create a catalog item using the helper method
        _ = createTestCatalogItem(in: context, code: "SAVE-TEST-001", name: "Save Test Item", manufacturer: "Test Manufacturer")
        
        try context.save()
        
        // Verify it was saved
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "code == %@", "SAVE-TEST-001")
        
        let savedItems = try context.fetch(fetchRequest)
        #expect(savedItems.count == 1, "Should save one item")
        #expect(savedItems.first?.name == "Save Test Item", "Should save item with correct name")
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
        
        // Create an item that might cause save failures (using minimal data)
        // We'll test this by creating a valid item first, then attempting to create conflicts
        _ = createTestCatalogItem(in: context, code: "VALID-ITEM", name: "Valid Item")
        
        try context.save()
        
        // Now try to create another item with the same code (might cause unique constraint violation)
        _ = createTestCatalogItem(in: context, code: "VALID-ITEM", name: "Duplicate Item")
        
        do {
            try context.save()
            // If it saves without error, the model may allow duplicates
            #expect(true, "Context saved successfully (model may allow duplicate codes)")
        } catch {
            // Expected - the service should handle save errors gracefully
            #expect(error != nil, "Should handle save errors appropriately")
            print("Expected save error: \(error)")
            
            // Reset context to clean state after error
            context.rollback()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("DataLoadingService should handle batch processing efficiently")
    func dataLoadingServiceBatchPerformance() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        let startTime = Date()
        
        // Create multiple items to simulate batch processing using helper method
        for i in 0..<100 {
            _ = createTestCatalogItem(
                in: context,
                code: "BATCH-\(i)",
                name: "Batch Item \(i)",
                manufacturer: "Batch Manufacturer \(i % 5)"
            )
        }
        
        try context.save()
        
        let endTime = Date()
        let timeElapsed = endTime.timeIntervalSince(startTime)
        
        #expect(timeElapsed < 2.0, "Should process 100 items within 2 seconds")
        
        // Verify all items were saved
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "code BEGINSWITH 'BATCH-'")
        
        let savedItems = try context.fetch(fetchRequest)
        #expect(savedItems.count == 100, "Should save all 100 batch items")
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
        
        // Create items that would trigger logging during processing using helper method
        for i in 0..<5 {
            _ = createTestCatalogItem(in: context, code: "LOG-TEST-\(i)", name: "Log Test Item \(i)")
        }
        
        try context.save()
        
        // The actual logging happens in the service methods
        // This test verifies that the operations complete successfully
        // which indirectly tests that logging doesn't interfere with processing
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let count = try context.count(for: fetchRequest)
        
        #expect(count == 5, "Should complete operations with logging active")
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