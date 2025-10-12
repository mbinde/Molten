//
//  UnifiedCoreDataServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import CoreData

@testable import Flameworker

// iOS only - use Swift Testing
#if canImport(Testing)
import Testing
#endif

// Use Swift Testing if available, otherwise fall back to XCTest
#if canImport(Testing)

@Suite("UnifiedCoreDataService Tests", .serialized)
struct UnifiedCoreDataServiceTests {
    
    // Test controller pool to prevent Core Data stack exhaustion (same as FetchRequestBuilderTests)
    private static var testControllerPool: [PersistenceController] = []
    private static let maxPoolSize = 3
    
    // Get a clean, reusable test controller instead of creating new ones
    private func getCleanTestController() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        print("🔧 Getting clean test controller from UnifiedCoreDataService pool...")
        
        // Try to find a clean controller from the pool first
        for (index, controller) in Self.testControllerPool.enumerated() {
            let context = controller.container.viewContext
            
            // Check if this controller's context is clean
            let entities = controller.container.managedObjectModel.entities
            var isClean = true
            
            for entityDescription in entities {
                guard let entityName = entityDescription.name else { continue }
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                
                do {
                    let existingItems = try context.fetch(fetchRequest)
                    if !existingItems.isEmpty {
                        print("  🧹 Controller \(index) has \(existingItems.count) \(entityName) items - cleaning...")
                        for item in existingItems {
                            context.delete(item)
                        }
                        try context.save()
                    }
                } catch {
                    print("  ⚠️ Controller \(index) cleanup failed for \(entityName): \(error)")
                    isClean = false
                    break
                }
            }
            
            if isClean {
                print("  ✅ Reusing cleaned controller \(index): \(ObjectIdentifier(controller))")
                return (controller, context)
            }
        }
        
        // If no clean controller available and pool isn't full, create a new one
        if Self.testControllerPool.count < Self.maxPoolSize {
            let newController = PersistenceController.createTestController()
            Self.testControllerPool.append(newController)
            let context = newController.container.viewContext
            print("  🆕 Created new controller \(Self.testControllerPool.count - 1): \(ObjectIdentifier(newController))")
            print("  📊 UnifiedCoreDataService Pool size: \(Self.testControllerPool.count)/\(Self.maxPoolSize)")
            return (newController, context)
        }
        
        // Pool is full and no clean controllers - force clean the first one
        let controller = Self.testControllerPool[0]
        let context = controller.container.viewContext
        
        print("  🧹 Pool full - force cleaning controller 0...")
        let entities = controller.container.managedObjectModel.entities
        for entityDescription in entities {
            guard let entityName = entityDescription.name else { continue }
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            
            do {
                let existingItems = try context.fetch(fetchRequest)
                for item in existingItems {
                    context.delete(item)
                }
            } catch {
                print("  ⚠️ Force cleanup failed for \(entityName): \(error)")
            }
        }
        
        try context.save()
        print("  ✅ Force cleaned controller 0: \(ObjectIdentifier(controller))")
        return (controller, context)
    }
    
    // Simple test context creation - for basic tests (DEPRECATED - use getCleanTestController)
    private func createCleanTestContext() -> NSManagedObjectContext {
        let testController = PersistenceController.createTestController()
        return testController.container.viewContext
    }
    
    // Helper method to create a properly configured test CatalogItem
    private func createValidTestCatalogItem(
        name: String,
        code: String,
        in context: NSManagedObjectContext,
        service: BaseCoreDataService<CatalogItem>
    ) -> CatalogItem {
        let entity = service.create(in: context)
        
        // Set only the essential fields to avoid validation issues
        entity.name = name
        entity.code = code
        entity.manufacturer = "Test Manufacturer"
        
        // Set optional fields using safe setValue to avoid crashes
        // Only set if the attribute exists
        if entity.entity.attributesByName["coe"] != nil {
            entity.setValue("TEST-COE", forKey: "coe")
        }
        if entity.entity.attributesByName["id"] != nil {
            entity.setValue(UUID().uuidString, forKey: "id")
        }
        if entity.entity.attributesByName["stock_type"] != nil {
            entity.setValue("standard", forKey: "stock_type")
        }
        
        return entity
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
        #expect(createdEntity != nil)
        #expect(createdEntity.managedObjectContext === context)
        #expect(createdEntity.entity.name == "CatalogItem")
    }
    
    @Test("Should fetch entities from context")
    func testFetchEntities() throws {
        // Arrange - Use shared pooled context to prevent stack exhaustion  
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Verify starting with clean context
        let initialCount = try service.count(in: context)
        #expect(initialCount == 0, "Context should start completely empty")
        
        // Create properly configured test entities
        let entity1 = createValidTestCatalogItem(
            name: "Test Item 1",
            code: "TEST-001",
            in: context,
            service: service
        )
        
        let entity2 = createValidTestCatalogItem(
            name: "Test Item 2",
            code: "TEST-002",
            in: context,
            service: service
        )
        
        // Verify entities were created before saving
        let unsavedCount = context.insertedObjects.count
        #expect(unsavedCount == 2, "Should have 2 unsaved entities")
        
        // Save the context so entities are available for fetch
        try CoreDataHelpers.safeSave(context: context, description: "Test entities")
        
        // Verify entities were saved
        let countAfterSave = try service.count(in: context)
        #expect(countAfterSave == 2, "Should have 2 entities after save")
        
        // Act
        let fetchedEntities = try service.fetch(in: context)
        
        // Assert
        #expect(fetchedEntities.count == 2, "Should have exactly our 2 test entities") 
        
        // Verify our test entities are in the results
        let testCodes = fetchedEntities.compactMap { $0.code }
        #expect(testCodes.contains("TEST-001"), "Should contain TEST-001")
        #expect(testCodes.contains("TEST-002"), "Should contain TEST-002")
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
    
    @Test("Should delete entity from context")
    func testDeleteEntity() throws {
        // Arrange - Use isolated test context
        let context = createCleanTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a properly configured test entity
        let entity = createValidTestCatalogItem(
            name: "Delete Me",
            code: "DELETE-001",
            in: context,
            service: service
        )
        
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
        
        // Create properly configured test entities
        let entity1 = createValidTestCatalogItem(
            name: "Item A",
            code: "COUNT-001",
            in: context,
            service: service
        )
        
        let entity2 = createValidTestCatalogItem(
            name: "Item B",
            code: "COUNT-002",
            in: context,
            service: service
        )
        
        let entity3 = createValidTestCatalogItem(
            name: "Special Item",
            code: "SPECIAL-001",
            in: context,
            service: service
        )
        
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
        // Arrange - Use shared pooled context to prevent stack exhaustion
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Verify completely clean starting state
        let initialCount = try service.count(in: context)
        #expect(initialCount == 0, "Context should start completely empty")
        
        // Create properly configured test entities with different categories
        let entity1 = createValidTestCatalogItem(
            name: "Keep Item 1",
            code: "KEEP-001",
            in: context,
            service: service
        )
        
        let entity2 = createValidTestCatalogItem(
            name: "Delete Item 1",
            code: "DELETE-001",
            in: context,
            service: service
        )
        
        let entity3 = createValidTestCatalogItem(
            name: "Delete Item 2",
            code: "DELETE-002",
            in: context,
            service: service
        )
        
        let entity4 = createValidTestCatalogItem(
            name: "Keep Item 2",
            code: "KEEP-002",
            in: context,
            service: service
        )
        
        // Verify all entities were created before saving
        let unsavedCount = context.insertedObjects.count
        #expect(unsavedCount == 4, "Should have 4 unsaved entities")
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "DeleteAll test entities")
        
        // Verify initial state after save
        let countAfterSave = try service.count(in: context)
        #expect(countAfterSave == 4, "Should have 4 entities after save")
        
        // Verify entities with DELETE codes exist before deletion
        let deleteEntitiesBeforeDelete = try service.count(
            predicate: NSPredicate(format: "code BEGINSWITH %@", "DELETE"),
            in: context
        )
        #expect(deleteEntitiesBeforeDelete == 2, "Should have 2 entities to delete")
        
        // Act - Delete entities with "DELETE" in the code
        print("🔧 Attempting to delete entities with DELETE prefix...")
        let deletedCount: Int
        do {
            deletedCount = try service.deleteAll(
                matching: NSPredicate(format: "code BEGINSWITH %@", "DELETE"),
                in: context
            )
            print("✅ Successfully deleted \(deletedCount) entities")
        } catch {
            print("❌ Delete operation failed: \(error)")
            
            // Diagnose the specific entities causing the issue
            let entitiesToDelete = try service.fetch(
                predicate: NSPredicate(format: "code BEGINSWITH %@", "DELETE"),
                in: context
            )
            
            print("🔍 Diagnosing \(entitiesToDelete.count) entities marked for deletion:")
            for (index, entity) in entitiesToDelete.enumerated() {
                print("  \(index + 1). \(entity.code ?? "nil"): \(entity.name ?? "nil")")
                print("     ObjectID: \(entity.objectID)")
                print("     HasChanges: \(entity.hasChanges)")
                print("     IsDeleted: \(entity.isDeleted)")
                print("     IsInserted: \(entity.isInserted)")
                print("     IsUpdated: \(entity.isUpdated)")
                
                // Check for potential relationship issues
                if let relationships = entity.entity.relationshipsByName {
                    for (relationshipName, relationshipDesc) in relationships {
                        if relationshipDesc.isOptional == false {
                            print("     Required relationship '\(relationshipName)': \(entity.value(forKey: relationshipName) ?? "nil")")
                        }
                    }
                }
            }
            
            throw error
        }
        
        // Assert - Verify deletion results
        #expect(deletedCount == 2, "Should have deleted 2 entities")
        
        let remainingCount = try service.count(in: context)
        #expect(remainingCount == 2, "Should have 2 entities left")
        
        // Verify the correct entities remain
        let remaining = try service.fetch(in: context)
        let remainingCodes = remaining.compactMap { $0.code }
        #expect(remainingCodes.contains("KEEP-001"), "Should contain KEEP-001")
        #expect(remainingCodes.contains("KEEP-002"), "Should contain KEEP-002")
        #expect(!remainingCodes.contains("DELETE-001"), "Should not contain DELETE-001")
        #expect(!remainingCodes.contains("DELETE-002"), "Should not contain DELETE-002")
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
    
    @Test("Should fetch with sorting and limit")
    func testFetchWithSortingAndLimit() throws {
        // Arrange - Use shared pooled context to prevent stack exhaustion
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Verify completely clean starting state
        let initialCount = try service.count(in: context)
        #expect(initialCount == 0, "Context should be completely empty at start")
        
        // Create properly configured test entities with different names for sorting
        let entity1 = createValidTestCatalogItem(
            name: "Charlie",
            code: "C-001",
            in: context,
            service: service
        )
        
        let entity2 = createValidTestCatalogItem(
            name: "Alpha",
            code: "A-001",
            in: context,
            service: service
        )
        
        let entity3 = createValidTestCatalogItem(
            name: "Beta",
            code: "B-001",
            in: context,
            service: service
        )
        
        let entity4 = createValidTestCatalogItem(
            name: "Delta",
            code: "D-001",
            in: context,
            service: service
        )
        
        // Verify all entities were created before saving
        let unsavedCount = context.insertedObjects.count
        #expect(unsavedCount == 4, "Should have 4 unsaved entities before save")
        
        // Save entities
        try CoreDataHelpers.safeSave(context: context, description: "Sorting test entities")
        
        // Verify all entities were saved
        let countAfterSave = try service.count(in: context)
        #expect(countAfterSave == 4, "Should have 4 entities after save")
        
        // Verify we have all expected entities before sorting
        let allEntitiesBeforeSort = try service.fetch(in: context)
        #expect(allEntitiesBeforeSort.count == 4, "Should have exactly 4 entities before sorting tests")
        
        // Act - Fetch with ascending sort by name, limit to 2
        let sortedLimited = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            limit: 2,
            in: context
        )
        
        // Assert - Should get first 2 alphabetically
        #expect(sortedLimited.count == 2, "Should get exactly 2 entities with limit")
        #expect(sortedLimited[0].name == "Alpha", "First entity should be Alpha")
        #expect(sortedLimited[1].name == "Beta", "Second entity should be Beta")
        
        // Act - Fetch with descending sort, no limit
        let sortedDesc = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
            in: context
        )
        
        // Assert - Should get all 4 in reverse alphabetical order with bounds checking
        #expect(sortedDesc.count == 4, "Should get all 4 entities without limit")
        
        // Add bounds checking to prevent crashes
        if sortedDesc.count >= 4 {
            #expect(sortedDesc[0].name == "Delta", "First entity should be Delta")
            #expect(sortedDesc[1].name == "Charlie", "Second entity should be Charlie")
            #expect(sortedDesc[2].name == "Beta", "Third entity should be Beta")
            #expect(sortedDesc[3].name == "Alpha", "Fourth entity should be Alpha")
        } else {
            throw NSError(domain: "Test", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected 4 entities but got \(sortedDesc.count). Entities found: \(sortedDesc.compactMap { $0.name })"
            ])
        }
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
}

#endif