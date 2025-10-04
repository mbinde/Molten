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
    
    @Test("Should verify PurchaseRecord entity exists and is properly configured")
    func testPurchaseRecordEntityConfiguration() {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let model = testController.container.managedObjectModel
        
        // Verify the PurchaseRecord entity exists in the model
        guard let purchaseRecordEntity = model.entitiesByName["PurchaseRecord"] else {
            Issue.record("PurchaseRecord entity not found in Core Data model")
            return
        }
        
        // Verify required attributes exist
        let requiredAttributes = ["supplier", "price", "date_added", "notes", "type", "units"]
        for attributeName in requiredAttributes {
            guard purchaseRecordEntity.attributesByName[attributeName] != nil else {
                Issue.record("Required attribute '\(attributeName)' not found in PurchaseRecord entity")
                return
            }
        }
        
        #expect(true, "PurchaseRecord entity is properly configured")
    }
    
    @Test("Should create PurchaseRecord entity without model conflicts")
    func testCreatePurchaseRecordWithoutModelConflicts() {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Verify we can create the entity
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "PurchaseRecord", in: context) else {
            Issue.record("Cannot find PurchaseRecord entity description")
            return
        }
        
        // Create the managed object
        let purchaseRecord = NSManagedObject(entity: entityDescription, insertInto: context)
        
        // Set basic properties to test compatibility
        purchaseRecord.setValue("Test Supplier", forKey: "supplier")
        purchaseRecord.setValue(100.0, forKey: "price")
        purchaseRecord.setValue(Date(), forKey: "date_added")
        
        // Verify the object was created successfully
        #expect(purchaseRecord.entity.name == "PurchaseRecord")
        #expect(purchaseRecord.value(forKey: "supplier") as? String == "Test Supplier")
    }
    
    @Test("Should save PurchaseRecord to isolated context successfully")  
    func testSavePurchaseRecordToIsolatedContext() async {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        await MainActor.run {
            // Create entity using NSManagedObject directly to avoid any custom class issues
            guard let entityDescription = NSEntityDescription.entity(forEntityName: "PurchaseRecord", in: context) else {
                Issue.record("Cannot find PurchaseRecord entity description")
                return
            }
            
            let purchaseRecord = NSManagedObject(entity: entityDescription, insertInto: context)
            purchaseRecord.setValue("Test Supplier Direct", forKey: "supplier")
            purchaseRecord.setValue(200.0, forKey: "price")
            purchaseRecord.setValue(Date(), forKey: "date_added")
            purchaseRecord.setValue("Direct test notes", forKey: "notes")
            purchaseRecord.setValue(Int16(0), forKey: "type")
            purchaseRecord.setValue(Int16(0), forKey: "units")
            
            do {
                try context.save()
                #expect(true, "Save should succeed for NSManagedObject")
            } catch {
                Issue.record("Save failed for NSManagedObject: \(error)")
            }
        }
    }
}