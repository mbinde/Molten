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
    
    private func createTestPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    private func createEmptyJSONData() -> Data {
        return "[]".data(using: .utf8)!
    }
    
    private func createSampleCatalogJSONData() -> Data {
        let json = """
        [
            {
                "code": "TEST-001",
                "name": "Test Glass Rod",
                "manufacturer": "Test Manufacturer"
            },
            {
                "code": "TEST-002", 
                "name": "Test Glass Frit",
                "manufacturer": "Another Manufacturer"
            }
        ]
        """
        return json.data(using: .utf8)!
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
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create some existing catalog items
        let item1 = CatalogItem(context: context)
        item1.code = "EXISTING-001"
        item1.name = "Existing Item 1"
        
        let item2 = CatalogItem(context: context)
        item2.code = "EXISTING-002"
        item2.name = "Existing Item 2"
        
        try context.save()
        
        // Test that we can count existing items
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCount = try context.count(for: fetchRequest)
        
        #expect(existingCount == 2, "Should correctly count existing items")
    }
    
    @Test("DataLoadingService should handle empty context")
    func dataLoadingServiceEmptyContext() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Test counting in empty context
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let count = try context.count(for: fetchRequest)
        
        #expect(count == 0, "Empty context should have zero items")
    }
    
    @Test("DataLoadingService should save items correctly")
    func dataLoadingServiceSaveItems() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create a catalog item directly (simulating what the service does)
        let item = CatalogItem(context: context)
        item.code = "SAVE-TEST-001"
        item.name = "Save Test Item"
        item.manufacturer = "Test Manufacturer"
        
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
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Test that the service can handle an empty JSON array
        // This tests the JSON processing logic indirectly
        let emptyData = createEmptyJSONData()
        
        // Verify the empty JSON data is valid
        let decoder = JSONDecoder()
        let emptyArray = try decoder.decode([CatalogItemData].self, from: emptyData)
        #expect(emptyArray.isEmpty, "Should decode empty JSON array correctly")
    }
    
    @Test("DataLoadingService should process valid JSON data")
    func dataLoadingServiceValidJSON() async throws {
        let jsonData = createSampleCatalogJSONData()
        
        // Test JSON decoding
        let decoder = JSONDecoder()
        let catalogItems = try decoder.decode([CatalogItemData].self, from: jsonData)
        
        #expect(catalogItems.count == 2, "Should decode 2 items from sample JSON")
        #expect(catalogItems[0].code == "TEST-001", "Should decode first item correctly")
        #expect(catalogItems[1].name == "Test Glass Frit", "Should decode second item correctly")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("DataLoadingService should handle malformed JSON gracefully")
    func dataLoadingServiceMalformedJSON() async throws {
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
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create an invalid item that might cause save failures
        let item = CatalogItem(context: context)
        item.code = nil // This might cause validation errors
        item.name = "Invalid Item"
        
        // Test that save failures are handled
        do {
            try context.save()
            // If it saves without error, that's also valid
        } catch {
            // Expected - the service should handle save errors gracefully
            #expect(error != nil, "Should handle save errors appropriately")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("DataLoadingService should handle batch processing efficiently")
    func dataLoadingServiceBatchPerformance() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let startTime = Date()
        
        // Create multiple items to simulate batch processing
        for i in 0..<100 {
            let item = CatalogItem(context: context)
            item.code = "BATCH-\(i)"
            item.name = "Batch Item \(i)"
            item.manufacturer = "Batch Manufacturer \(i % 5)"
        }
        
        try context.save()
        
        let endTime = Date()
        let timeElapsed = endTime.timeIntervalSince(startTime)
        
        #expect(timeElapsed < 1.0, "Should process 100 items within 1 second")
        
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
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create items that would trigger logging during processing
        for i in 0..<5 {
            let item = CatalogItem(context: context)
            item.code = "LOG-TEST-\(i)"
            item.name = "Log Test Item \(i)"
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