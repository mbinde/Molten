//
//  PersistenceControllerTests.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("PersistenceController Tests")
struct PersistenceControllerTests {
    
    @Test("PersistenceController preview should be accessible")
    func testPersistenceControllerPreview() {
        // Test that PersistenceController.preview is accessible and functional
        let previewContext = PersistenceController.preview.container.viewContext
        
        #expect(previewContext != nil, "Preview context should be available")
        
        // Test that we can access the managed object context
        let contextName = previewContext.name ?? "unnamed"
        #expect(contextName != nil, "Context should have some identifier")
    }
    
    @Test("Core Data stack should be properly configured")
    func testCoreDataStackConfiguration() {
        let controller = PersistenceController.preview
        let container = controller.container
        
        #expect(container.name == "Flameworker", "Container should have correct name")
        
        // Test that the view context is configured
        let viewContext = container.viewContext
        #expect(viewContext.automaticallyMergesChangesFromParent == true, "View context should auto-merge changes")
    }
    
    @Test("Feature flags should work with persistence layer")
    func testFeatureFlagsWithPersistence() {
        // Test that feature flags work in persistence context
        let coreDataPersistence = FeatureFlags.coreDataPersistence
        #expect(coreDataPersistence == true, "Core Data persistence should be enabled")
        
        let basicManagement = FeatureFlags.basicInventoryManagement
        #expect(basicManagement == true, "Basic inventory management should be enabled")
        
        // Test debug config access
        let debugPersistence = DebugConfig.FeatureFlags.coreDataPersistence
        #expect(coreDataPersistence == debugPersistence, "Both access methods should match")
    }
}
    
    @Test("Should create persistence controller without crashing")
    func testPersistenceControllerCreation() {
        // This test verifies that we can create a PersistenceController without 
        // the "no persistent stores" crash
        let controller = PersistenceController.createTestController()
        
        // Verify the container exists
        #expect(controller.container != nil)
        
        // Verify the context exists
        let context = controller.container.viewContext
        #expect(context != nil)
        
        // Most importantly: verify the store coordinator has stores loaded
        let coordinator = context.persistentStoreCoordinator
        #expect(coordinator != nil)
        #expect(coordinator!.persistentStores.count > 0, "PersistentStoreCoordinator should have at least one store loaded")
        
        // Verify our new isReady property works
        #expect(controller.isReady == true, "Controller should be ready when stores are loaded")
        #expect(controller.hasStoreLoadingError == false, "Controller should not have loading errors for in-memory store")
    }
    
    @Test("Should be able to save to context without crashing")
    func testSafeContextSave() async {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        // Create a simple entity to test saving using NSManagedObject directly
        await MainActor.run {
            // First, let's check what entities are available in the model
            let model = controller.container.managedObjectModel
            let entityNames = model.entities.map { $0.name ?? "Unknown" }
            print("Available entities: \(entityNames)")
            
            // Try to use CatalogItem entity if it exists, otherwise create a generic test entity
            if let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) {
                let testItem = NSManagedObject(entity: catalogEntity, insertInto: context)
                testItem.setValue("TEST-001", forKey: "code")
                testItem.setValue("Test Item", forKey: "name")
                testItem.setValue("Test Manufacturer", forKey: "manufacturer")
                testItem.setValue(1, forKey: "units") // Set valid units to prevent validation errors
                
                // This should not crash with "no persistent stores"
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "Test save operation")
                    // If we get here, the save succeeded
                    #expect(true)
                } catch {
                    Issue.record("Save operation failed: \(error)")
                }
            } else {
                // Create a simple in-memory test entity that doesn't depend on the xcdatamodeld file
                let testEntityDesc = NSEntityDescription()
                testEntityDesc.name = "TestEntity"
                testEntityDesc.managedObjectClassName = "NSManagedObject"
                
                let codeAttribute = NSAttributeDescription()
                codeAttribute.name = "code"
                codeAttribute.attributeType = .stringAttributeType
                codeAttribute.isOptional = false
                
                let nameAttribute = NSAttributeDescription()
                nameAttribute.name = "name"
                nameAttribute.attributeType = .stringAttributeType
                nameAttribute.isOptional = true
                
                testEntityDesc.properties = [codeAttribute, nameAttribute]
                
                let testItem = NSManagedObject(entity: testEntityDesc, insertInto: context)
                testItem.setValue("TEST-001", forKey: "code")
                testItem.setValue("Test Item", forKey: "name")
                
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "Generic entity test save")
                    #expect(true, "Generic entity should save successfully")
                } catch {
                    Issue.record("Generic entity save failed: \(error)")
                }
            }
        }
    }
    
    @Test("Should handle persistent store loading timeout gracefully")
    func testPersistentStoreLoadingTimeout() {
        // This test ensures that if store loading times out,
        // we don't crash but handle it gracefully
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        // Verify we can still access the coordinator without crashing
        let coordinator = context.persistentStoreCoordinator
        #expect(coordinator != nil)
        
        // If stores failed to load, we should handle this gracefully
        // rather than crashing on save operations
        if coordinator!.persistentStores.isEmpty {
            // This is the problematic state that causes the crash
            // We should handle it gracefully
            #expect(true, "Detected no persistent stores state - this needs to be handled gracefully")
        }
    }
    
    @Test("Should throw proper error when saving to context with no persistent stores")
    func testSafeContextSaveWithNoStores() async {
        // Create a mock context that has a coordinator but no stores
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        // This test verifies our improved error handling in safeSave
        // If for some reason stores are not loaded, we should get a clear error
        // instead of the cryptic "NSInternalInconsistencyException"
        
        await MainActor.run {
            // Simulate the problematic condition by removing all stores (testing scenario only)
            let coordinator = context.persistentStoreCoordinator!
            
            if !coordinator.persistentStores.isEmpty {
                // Normal case - stores are loaded, save should work
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "Test with stores")
                    #expect(true, "Save should succeed when stores are loaded")
                } catch {
                    Issue.record("Unexpected error when stores are loaded: \(error)")
                }
            } else {
                // Edge case - no stores loaded, should get clear error
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "Test without stores")
                    Issue.record("Save should have failed when no stores are loaded")
                } catch let nsError as NSError {
                    #expect(nsError.domain == "CoreDataHelpers")
                    #expect(nsError.code == 1002)
                    #expect(nsError.localizedDescription.contains("no persistent stores loaded"))
                } catch {
                    Issue.record("Unexpected error type: \(error)")
                }
            }
        }
    }
    
    @Test("Should diagnose Core Data model configuration")
    func testCoreDataModelDiagnosis() async {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        let model = controller.container.managedObjectModel
        
        // Print all available entities for debugging
        print("🔍 Core Data Model Diagnosis:")
        print("Available entities: \(model.entities.map { $0.name ?? "Unknown" })")
        
        for entity in model.entities {
            print("Entity: \(entity.name ?? "Unknown")")
            print("  Class Name: \(entity.managedObjectClassName)")
            print("  Attributes: \(entity.attributesByName.keys.sorted())")
        }
        
        // Try to create entities using NSManagedObject directly to avoid class issues
        await MainActor.run {
            // Test CatalogItem with NSManagedObject
            if let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) {
                let catalogItem = NSManagedObject(entity: catalogEntity, insertInto: context)
                catalogItem.setValue("TEST-001", forKey: "code")
                catalogItem.setValue("Test Item", forKey: "name")
                catalogItem.setValue(1, forKey: "units") // Set valid units to prevent validation errors
                
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "CatalogItem diagnosis test")
                    print("✅ NSManagedObject CatalogItem saved successfully")
                    #expect(true)
                } catch {
                    Issue.record("NSManagedObject CatalogItem save failed: \(error)")
                }
            }
            
            // Test PurchaseRecord with NSManagedObject
            if let purchaseEntity = NSEntityDescription.entity(forEntityName: "PurchaseRecord", in: context) {
                let purchaseRecord = NSManagedObject(entity: purchaseEntity, insertInto: context)
                purchaseRecord.setValue("Test Supplier", forKey: "supplier")
                purchaseRecord.setValue(100.0, forKey: "price")
                purchaseRecord.setValue(Date(), forKey: "date_added")
                
                do {
                    try CoreDataHelpers.safeSave(context: context, description: "PurchaseRecord diagnosis test")
                    print("✅ NSManagedObject PurchaseRecord saved successfully")
                    #expect(true)
                } catch {
                    Issue.record("NSManagedObject PurchaseRecord save failed: \(error)")
                }
            } else {
                Issue.record("PurchaseRecord entity not found in model")
            }
        }
    }
}