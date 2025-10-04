//
//  CoreDataModelTests.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Model Tests")
struct CoreDataModelTests {
    
    @Test("Should verify CatalogItem entity exists and is properly configured")
    func testCatalogItemEntityConfiguration() {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let model = testController.container.managedObjectModel
        
        // Verify the CatalogItem entity exists in the model (this should work)
        guard let catalogItemEntity = model.entitiesByName["CatalogItem"] else {
            Issue.record("CatalogItem entity not found in Core Data model")
            return
        }
        
        // Verify some expected attributes exist
        let expectedAttributes = ["id", "code", "name", "manufacturer"]
        for attributeName in expectedAttributes {
            guard catalogItemEntity.attributesByName[attributeName] != nil else {
                Issue.record("Expected attribute '\(attributeName)' not found in CatalogItem entity")
                return
            }
        }
        
        #expect(true, "CatalogItem entity is properly configured")
    }
    
    @Test("Should create CatalogItem entity without model conflicts")
    func testCreateCatalogItemWithoutModelConflicts() {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Create a CatalogItem - this should work since it exists in the model
        let catalogItem = CatalogItem(context: context)
        catalogItem.id = "test-id-001"
        catalogItem.code = "TEST-CODE"
        catalogItem.name = "Test Item"
        catalogItem.manufacturer = "Test Manufacturer"
        
        // Verify the object was created successfully
        #expect(catalogItem.entity.name == "CatalogItem")
        #expect(catalogItem.id == "test-id-001")
        #expect(catalogItem.code == "TEST-CODE")
        #expect(catalogItem.name == "Test Item")
        #expect(catalogItem.manufacturer == "Test Manufacturer")
    }
    
    @Test("Should save CatalogItem to isolated context successfully")  
    func testSaveCatalogItemToIsolatedContext() async {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        await MainActor.run {
            let catalogItem = CatalogItem(context: context)
            catalogItem.id = "save-test-001"
            catalogItem.code = "SAVE-TEST"
            catalogItem.name = "Save Test Item"
            catalogItem.manufacturer = "Save Test Manufacturer"
            catalogItem.coe = "COE104"
            
            do {
                try context.save()
                #expect(true, "Save should succeed for CatalogItem")
                
                // Verify the item was saved
                let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
                fetchRequest.predicate = NSPredicate(format: "id == %@", "save-test-001")
                
                let savedItems = try context.fetch(fetchRequest)
                #expect(savedItems.count == 1, "Should have saved exactly one item")
                #expect(savedItems.first?.id == "save-test-001")
                
            } catch {
                Issue.record("Save failed for CatalogItem: \(error)")
            }
        }
    }
    
    @Test("Should diagnose actual model structure")
    func testDiagnoseActualModelStructure() {
        let testController = PersistenceController.createTestController()
        
        // Use the recovery utility to diagnose what's actually in the model
        CoreDataRecoveryUtility.diagnoseModel(testController)
        
        let model = testController.container.managedObjectModel
        let entityNames = model.entities.compactMap { $0.name }
        
        // We know CatalogItem should exist
        #expect(entityNames.contains("CatalogItem"), "CatalogItem should exist in the model")
        
        // Print for debugging - this will help understand what entities actually exist
        print("📋 Entities found in model: \(entityNames.sorted())")
        
        #expect(true, "Model diagnosis completed successfully")
    }
}