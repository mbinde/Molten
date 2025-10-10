//
//  UnifiedCoreDataServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import CoreData

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

// Use Swift Testing if available, otherwise fall back to XCTest
#if canImport(Testing)

@Suite("UnifiedCoreDataService Tests")
struct UnifiedCoreDataServiceTests {
    
    // Helper method to create clean test context for each test
    private func createCleanTestContext() -> NSManagedObjectContext {
        // Use createTestController for complete isolation
        let testController = PersistenceController.createTestController()
        return testController.container.viewContext
    }
    
    @Test("Should create new entity in context")
    func testCreateEntity() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        
        // Create a service for CatalogItem (which exists in our Core Data model)
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Act
        let createdEntity = service.create(in: context)
        
        // Assert
        // No need to check for nil - create() returns non-optional CatalogItem
        #expect(createdEntity.managedObjectContext === context)
        #expect(createdEntity.entity.name == "CatalogItem")
    }
    
    @Test("Should fetch entities from context")
    func testFetchEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a few test entities first
        let entity1 = service.create(in: context)
        entity1.name = "Test Item 1"
        entity1.code = "TEST-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Test Item 2" 
        entity2.code = "TEST-002"
        
        // Save the context so entities are available for fetch
        try CoreDataHelpers.safeSave(context: context, description: "Test entities")
        
        // Act
        let fetchedEntities = try service.fetch(in: context)
        
        // Assert
        #expect(fetchedEntities.count == 2) // Should have exactly our test entities
        
        // Verify our test entities are in the results
        let testCodes = fetchedEntities.compactMap { $0.code }
        #expect(testCodes.contains("TEST-001"))
        #expect(testCodes.contains("TEST-002"))
    }
    
    @Test("Should delete entity from context")
    func testDeleteEntity() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a test entity
        let entity = service.create(in: context)
        entity.name = "Delete Me"
        entity.code = "DELETE-001"
        
        // Save the entity first
        try CoreDataHelpers.safeSave(context: context, description: "Entity to delete")
        
        // Verify it exists
        let beforeDelete = try service.fetch(predicate: NSPredicate(format: "code == %@", "DELETE-001"), in: context)
        #expect(beforeDelete.count == 1)
        
        // Act - Delete the entity
        try service.delete(entity, from: context, description: "Test deletion")
        
        // Assert - Verify it's gone
        let afterDelete = try service.fetch(predicate: NSPredicate(format: "code == %@", "DELETE-001"), in: context)
        #expect(afterDelete.count == 0)
    }
    
    @Test("Should count entities correctly")
    func testCountEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Initially should have no entities
        let initialCount = try service.count(in: context)
        #expect(initialCount == 0)
        
        // Create some test entities
        let entity1 = service.create(in: context)
        entity1.name = "Item A"
        entity1.code = "COUNT-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Item B"
        entity2.code = "COUNT-002"
        
        let entity3 = service.create(in: context)
        entity3.name = "Special Item"
        entity3.code = "SPECIAL-001"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "Count test entities")
        
        // Act & Assert - Count all entities
        let totalCount = try service.count(in: context)
        #expect(totalCount == 3)
        
        // Act & Assert - Count with predicate
        let specialCount = try service.count(
            predicate: NSPredicate(format: "name CONTAINS %@", "Special"),
            in: context
        )
        #expect(specialCount == 1)
    }
    
    @Test("Should delete all entities with predicate")
    func testDeleteAllEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test entities with different categories
        let entity1 = service.create(in: context)
        entity1.name = "Keep Item 1"
        entity1.code = "KEEP-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Delete Item 1"
        entity2.code = "DELETE-001"
        
        let entity3 = service.create(in: context)
        entity3.name = "Delete Item 2"
        entity3.code = "DELETE-002"
        
        let entity4 = service.create(in: context)
        entity4.name = "Keep Item 2"
        entity4.code = "KEEP-002"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "DeleteAll test entities")
        
        // Verify initial state
        let initialCount = try service.count(in: context)
        #expect(initialCount == 4)
        
        // Act - Delete entities with "DELETE" in the code
        let deletedCount = try service.deleteAll(
            matching: NSPredicate(format: "code BEGINSWITH %@", "DELETE"),
            in: context
        )
        
        // Assert - Verify deletion results
        #expect(deletedCount == 2) // Should have deleted 2 entities
        
        let remainingCount = try service.count(in: context)
        #expect(remainingCount == 2) // Should have 2 entities left
        
        // Verify the correct entities remain
        let remaining = try service.fetch(in: context)
        let remainingCodes = remaining.compactMap { $0.code }
        #expect(remainingCodes.contains("KEEP-001"))
        #expect(remainingCodes.contains("KEEP-002"))
        #expect(!remainingCodes.contains("DELETE-001"))
        #expect(!remainingCodes.contains("DELETE-002"))
    }
    
    @Test("Should fetch with sorting and limit")
    func testFetchWithSortingAndLimit() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test entities with different names for sorting
        let entity1 = service.create(in: context)
        entity1.name = "Charlie"
        entity1.code = "C-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Alpha"
        entity2.code = "A-001"
        
        let entity3 = service.create(in: context)
        entity3.name = "Beta"
        entity3.code = "B-001"
        
        let entity4 = service.create(in: context)
        entity4.name = "Delta"
        entity4.code = "D-001"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "Sorting test entities")
        
        // Act - Fetch with ascending sort by name, limit to 2
        let sortedLimited = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            limit: 2,
            in: context
        )
        
        // Assert - Should get first 2 alphabetically
        #expect(sortedLimited.count == 2)
        #expect(sortedLimited[0].name == "Alpha")
        #expect(sortedLimited[1].name == "Beta")
        
        // Act - Fetch with descending sort, no limit
        let sortedDesc = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
            in: context
        )
        
        // Assert - Should get all 4 in reverse alphabetical order
        #expect(sortedDesc.count == 4)
        #expect(sortedDesc[0].name == "Delta")
        #expect(sortedDesc[1].name == "Charlie")
        #expect(sortedDesc[2].name == "Beta")
        #expect(sortedDesc[3].name == "Alpha")
    }
}

#else

// Fallback to XCTest if Swift Testing is not available
class UnifiedCoreDataServiceTests: XCTestCase {
    
    // Helper method to create clean test context for each test
    private func createCleanTestContext() -> NSManagedObjectContext {
        // Use createTestController for complete isolation
        let testController = PersistenceController.createTestController()
        return testController.container.viewContext
    }
    
    func testCreateEntity() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        
        // Create a service for CatalogItem (which exists in our Core Data model)
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Act
        let createdEntity = service.create(in: context)
        
        // Assert
        // No need to check for nil - create() returns non-optional CatalogItem
        XCTAssertTrue(createdEntity.managedObjectContext === context)
        XCTAssertEqual(createdEntity.entity.name, "CatalogItem")
    }
    
    func testFetchEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a few test entities first
        let entity1 = service.create(in: context)
        entity1.name = "Test Item 1"
        entity1.code = "TEST-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Test Item 2" 
        entity2.code = "TEST-002"
        
        // Save the context so entities are available for fetch
        try CoreDataHelpers.safeSave(context: context, description: "Test entities")
        
        // Act
        let fetchedEntities = try service.fetch(in: context)
        
        // Assert
        XCTAssertEqual(fetchedEntities.count, 2) // Should have exactly our test entities
        
        // Verify our test entities are in the results
        let testCodes = fetchedEntities.compactMap { $0.code }
        XCTAssertTrue(testCodes.contains("TEST-001"))
        XCTAssertTrue(testCodes.contains("TEST-002"))
    }
    
    func testDeleteEntity() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a test entity
        let entity = service.create(in: context)
        entity.name = "Delete Me"
        entity.code = "DELETE-001"
        
        // Save the entity first
        try CoreDataHelpers.safeSave(context: context, description: "Entity to delete")
        
        // Verify it exists
        let beforeDelete = try service.fetch(predicate: NSPredicate(format: "code == %@", "DELETE-001"), in: context)
        XCTAssertEqual(beforeDelete.count, 1)
        
        // Act - Delete the entity
        try service.delete(entity, from: context, description: "Test deletion")
        
        // Assert - Verify it's gone
        let afterDelete = try service.fetch(predicate: NSPredicate(format: "code == %@", "DELETE-001"), in: context)
        XCTAssertEqual(afterDelete.count, 0)
    }
    
    func testCountEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Initially should have no entities
        let initialCount = try service.count(in: context)
        XCTAssertEqual(initialCount, 0)
        
        // Create some test entities
        let entity1 = service.create(in: context)
        entity1.name = "Item A"
        entity1.code = "COUNT-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Item B"
        entity2.code = "COUNT-002"
        
        let entity3 = service.create(in: context)
        entity3.name = "Special Item"
        entity3.code = "SPECIAL-001"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "Count test entities")
        
        // Act & Assert - Count all entities
        let totalCount = try service.count(in: context)
        XCTAssertEqual(totalCount, 3)
        
        // Act & Assert - Count with predicate
        let specialCount = try service.count(
            predicate: NSPredicate(format: "name CONTAINS %@", "Special"),
            in: context
        )
        XCTAssertEqual(specialCount, 1)
    }
    
    func testDeleteAllEntities() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test entities with different categories
        let entity1 = service.create(in: context)
        entity1.name = "Keep Item 1"
        entity1.code = "KEEP-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Delete Item 1"
        entity2.code = "DELETE-001"
        
        let entity3 = service.create(in: context)
        entity3.name = "Delete Item 2"
        entity3.code = "DELETE-002"
        
        let entity4 = service.create(in: context)
        entity4.name = "Keep Item 2"
        entity4.code = "KEEP-002"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "DeleteAll test entities")
        
        // Verify initial state
        let initialCount = try service.count(in: context)
        XCTAssertEqual(initialCount, 4)
        
        // Act - Delete entities with "DELETE" in the code
        let deletedCount = try service.deleteAll(
            matching: NSPredicate(format: "code BEGINSWITH %@", "DELETE"),
            in: context
        )
        
        // Assert - Verify deletion results
        XCTAssertEqual(deletedCount, 2) // Should have deleted 2 entities
        
        let remainingCount = try service.count(in: context)
        XCTAssertEqual(remainingCount, 2) // Should have 2 entities left
        
        // Verify the correct entities remain
        let remaining = try service.fetch(in: context)
        let remainingCodes = remaining.compactMap { $0.code }
        XCTAssertTrue(remainingCodes.contains("KEEP-001"))
        XCTAssertTrue(remainingCodes.contains("KEEP-002"))
        XCTAssertFalse(remainingCodes.contains("DELETE-001"))
        XCTAssertFalse(remainingCodes.contains("DELETE-002"))
    }
    
    func testFetchWithSortingAndLimit() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test entities with different names for sorting
        let entity1 = service.create(in: context)
        entity1.name = "Charlie"
        entity1.code = "C-001"
        
        let entity2 = service.create(in: context)
        entity2.name = "Alpha"
        entity2.code = "A-001"
        
        let entity3 = service.create(in: context)
        entity3.name = "Beta"
        entity3.code = "B-001"
        
        let entity4 = service.create(in: context)
        entity4.name = "Delta"
        entity4.code = "D-001"
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "Sorting test entities")
        
        // Act - Fetch with ascending sort by name, limit to 2
        let sortedLimited = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            limit: 2,
            in: context
        )
        
        // Assert - Should get first 2 alphabetically
        XCTAssertEqual(sortedLimited.count, 2)
        XCTAssertEqual(sortedLimited[0].name, "Alpha")
        XCTAssertEqual(sortedLimited[1].name, "Beta")
        
        // Act - Fetch with descending sort, no limit
        let sortedDesc = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
            in: context
        )
        
        // Assert - Should get all 4 in reverse alphabetical order
        XCTAssertEqual(sortedDesc.count, 4)
        XCTAssertEqual(sortedDesc[0].name, "Delta")
        XCTAssertEqual(sortedDesc[1].name, "Charlie")
        XCTAssertEqual(sortedDesc[2].name, "Beta")
        XCTAssertEqual(sortedDesc[3].name, "Alpha")
    }
}

#endif