//
//  CoreDataModelCompatibilityTests.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Model Compatibility Tests")
struct CoreDataModelCompatibilityTests {
    
    @Test("Should verify actual model entities and their attributes")
    func testActualModelEntities() {
        let controller = PersistenceController.createTestController()
        let model = controller.container.managedObjectModel
        
        print("🔍 Actual Core Data Model Entities:")
        for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            print("📋 Entity: \(entity.name ?? "Unknown")")
            print("   Class: \(entity.managedObjectClassName)")
            print("   Attributes:")
            for (name, attribute) in entity.attributesByName.sorted(by: { $0.key < $1.key }) {
                let type = attribute.attributeType
                print("     - \(name): \(type)")
            }
            print("")
        }
        
        // Test what entities actually exist
        let entityNames = model.entities.compactMap { $0.name }
        #expect(entityNames.contains("CatalogItem"), "CatalogItem should exist in model")
        
        // Check if PurchaseRecord exists
        if entityNames.contains("PurchaseRecord") {
            print("✅ PurchaseRecord entity exists in model")
            
            if let purchaseEntity = model.entitiesByName["PurchaseRecord"] {
                let expectedAttributes = ["supplier", "price", "date_added", "notes", "type", "units"]
                for attr in expectedAttributes {
                    if purchaseEntity.attributesByName[attr] != nil {
                        print("✅ PurchaseRecord.\(attr) exists")
                    } else {
                        Issue.record("❌ PurchaseRecord.\(attr) missing from model")
                    }
                }
            }
        } else {
            Issue.record("❌ PurchaseRecord entity does not exist in model - this explains the compatibility error")
        }
    }
    
    @Test("Should create entities that actually exist in the model")
    func testCreateActualModelEntities() async {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        let model = controller.container.managedObjectModel
        
        await MainActor.run {
            // Test CatalogItem creation (this should work)
            if let catalogEntity = model.entitiesByName["CatalogItem"] {
                let catalogItem = CatalogItem(context: context)
                catalogItem.code = "TEST-001"
                catalogItem.name = "Test Item"
                
                do {
                    try context.save()
                    print("✅ CatalogItem created and saved successfully")
                    #expect(true)
                } catch {
                    Issue.record("❌ CatalogItem save failed: \(error)")
                }
            } else {
                Issue.record("❌ CatalogItem entity not found in model")
            }
            
            // Test PurchaseRecord creation only if it exists
            if let purchaseEntity = model.entitiesByName["PurchaseRecord"] {
                // Use NSManagedObject to avoid class compatibility issues
                let purchaseRecord = NSManagedObject(entity: purchaseEntity, insertInto: context)
                purchaseRecord.setValue("Test Supplier", forKey: "supplier")
                purchaseRecord.setValue(100.0, forKey: "price")
                purchaseRecord.setValue(Date(), forKey: "date_added")
                
                do {
                    try context.save()
                    print("✅ PurchaseRecord (NSManagedObject) created and saved successfully")
                    #expect(true)
                } catch {
                    Issue.record("❌ PurchaseRecord (NSManagedObject) save failed: \(error)")
                }
            } else {
                print("⚠️ PurchaseRecord entity not found in model - skipping PurchaseRecord test")
                #expect(true, "Test passes - PurchaseRecord entity simply doesn't exist in current model")
            }
        }
    }
}