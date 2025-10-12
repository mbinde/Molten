//
//  FetchRequestBuilderTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData

@testable import Flameworker

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(Testing)

@Suite("FetchRequestBuilder Tests", .serialized)
struct FetchRequestBuilderTests {
    
    // Use completely isolated test context for reliability
    private func createCompletelyIsolatedTestContext() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Verify context is completely clean
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let existingCount = try context.count(for: fetchRequest)
        
        if existingCount != 0 {
            print("⚠️ FetchRequestBuilder test context not clean, found \(existingCount) existing items - cleaning up")
            let existingItems = try context.fetch(fetchRequest)
            for item in existingItems {
                context.delete(item)
            }
            try context.save()
        }
        
        return (testController, context)
    }
    
    // Helper to create test data with proper validation and cleanup
    private func createTestCatalogItems(in context: NSManagedObjectContext) throws {
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create diverse test data with all required fields to prevent save errors
        let item1 = service.create(in: context)
        item1.name = "Red Glass Rod"
        item1.code = "RGR-001"
        item1.manufacturer = "Bullseye Glass"
        
        let item2 = service.create(in: context)
        item2.name = "Blue Glass Sheet"
        item2.code = "BGS-002"
        item2.manufacturer = "Spectrum Glass"
        
        let item3 = service.create(in: context)
        item3.name = "Green Glass Frit"
        item3.code = "GGF-003"
        item3.manufacturer = "Bullseye Glass"
        
        let item4 = service.create(in: context)
        item4.name = "Clear Glass Rod"
        item4.code = "CGR-004"
        item4.manufacturer = "Spectrum Glass"
        
        // Save and verify all items were created
        try CoreDataHelpers.safeSave(context: context, description: "Test catalog items")
        
        // Verify we have exactly 4 items
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let savedCount = try context.count(for: fetchRequest)
        if savedCount != 4 {
            throw NSError(domain: "TestSetup", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected 4 test items but found \(savedCount)"
            ])
        }
    }
    
    @Test("Should build compound AND predicate")
    func testCompoundAndPredicate() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        // Act - Find items that are glass AND from Bullseye
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Glass"))
            .and(NSPredicate(format: "manufacturer == %@", "Bullseye Glass"))
            .execute(in: context)
        
        // Assert
        #expect(results.count == 2, "Should find 2 Bullseye glass items")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Green Glass Frit"), "Should contain Green Glass Frit")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should build compound OR predicate")
    func testCompoundOrPredicate() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        // Act - Find items that are either Red OR Blue
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Red"))
            .or(NSPredicate(format: "name CONTAINS[cd] %@", "Blue"))
            .execute(in: context)
        
        // Assert
        #expect(results.count == 2, "Should find 2 items (Red or Blue)")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Blue Glass Sheet"), "Should contain Blue Glass Sheet")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should get distinct values with filtering")
    func testDistinctValuesWithFiltering() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        // Debug: Let's verify our test data first
        let allRods = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Rod"))
            .execute(in: context)
        
        print("🔍 Debug: Found \(allRods.count) Rod items:")
        for rod in allRods {
            print("  - \(rod.name ?? "nil") by \(rod.manufacturer ?? "nil")")
        }
        
        // Act - Get distinct manufacturers only for Rod items
        let distinctManufacturers = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Rod"))
            .distinct(keyPath: "manufacturer", in: context)
        
        print("🔍 Debug: Distinct manufacturers: \(distinctManufacturers)")
        
        // Assert
        #expect(distinctManufacturers.count == 2, "Should have 2 distinct manufacturers for Rod items")
        #expect(distinctManufacturers.contains("Bullseye Glass"), "Should contain Bullseye Glass")
        #expect(distinctManufacturers.contains("Spectrum Glass"), "Should contain Spectrum Glass")
        
        // Keep reference to test controller
        _ = testController
    }
}

#endif