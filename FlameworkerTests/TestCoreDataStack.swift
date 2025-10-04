//
//  TestCoreDataStack.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

/// A programmatically created Core Data stack for testing that ensures all required entities exist
class TestCoreDataStack {
    
    static func createTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create CatalogItem entity
        let catalogItemEntity = NSEntityDescription()
        catalogItemEntity.name = "CatalogItem"
        catalogItemEntity.managedObjectClassName = NSStringFromClass(CatalogItem.self)
        
        // CatalogItem attributes
        let catalogAttributes: [(String, NSAttributeType)] = [
            ("id", .stringAttributeType),
            ("code", .stringAttributeType),
            ("name", .stringAttributeType),
            ("manufacturer", .stringAttributeType),
            ("manufacturer_description", .stringAttributeType),
            ("manufacturer_url", .stringAttributeType),
            ("image_path", .stringAttributeType),
            ("image_url", .stringAttributeType),
            ("coe", .stringAttributeType),
            ("stock_type", .stringAttributeType),
            ("synonyms", .stringAttributeType),
            ("tags", .stringAttributeType)
        ]
        
        catalogItemEntity.properties = catalogAttributes.map { (name, type) in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = true
            return attribute
        }
        
        // Create PurchaseRecord entity
        let purchaseRecordEntity = NSEntityDescription()
        purchaseRecordEntity.name = "PurchaseRecord"
        purchaseRecordEntity.managedObjectClassName = NSStringFromClass(PurchaseRecord.self)
        
        // PurchaseRecord attributes
        let purchaseAttributes: [(String, NSAttributeType, Bool)] = [
            ("supplier", .stringAttributeType, true),
            ("price", .doubleAttributeType, false),
            ("date_added", .dateAttributeType, true),
            ("notes", .stringAttributeType, true),
            ("type", .integer16AttributeType, false),
            ("units", .integer16AttributeType, false),
            ("id", .stringAttributeType, true),
            ("catalog_code", .stringAttributeType, true),
            ("count", .doubleAttributeType, false)
        ]
        
        purchaseRecordEntity.properties = purchaseAttributes.map { (name, type, optional) in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            if !optional && type == .doubleAttributeType {
                attribute.defaultValue = 0.0
            } else if !optional && type == .integer16AttributeType {
                attribute.defaultValue = 0
            }
            return attribute
        }
        
        model.entities = [catalogItemEntity, purchaseRecordEntity]
        return model
    }
    
    static func createTestContainer() -> NSPersistentContainer {
        // Create a custom persistence container with our programmatic model
        let testModel = createTestModel()
        let container = NSPersistentContainer(name: "TestModel", managedObjectModel: testModel)
        
        // Use in-memory store
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        // Load the store synchronously for testing
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            fatalError("Test Core Data stack failed to load: \(error)")
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }
}