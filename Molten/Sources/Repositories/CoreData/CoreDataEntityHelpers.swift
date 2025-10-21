//
//  CoreDataEntityHelpers.swift
//  Flameworker
//
//  Created by Assistant on 10/6/25.
//  Provides safe entity creation and fetch request helpers to prevent iPhone 17 entity resolution issues
//

@preconcurrency import CoreData
import OSLog
import Foundation

/// Helper utilities for safely creating Core Data entities and fetch requests
/// Use these methods instead of direct NSFetchRequest and entity creation to avoid entity resolution issues
struct CoreDataEntityHelpers {
    private static let log = Logger(subsystem: "com.flameworker.app", category: "core-data-helpers")
    
    // MARK: - Safe Fetch Request Creation
    
    /// Creates a safe fetch request for CatalogItem with proper entity resolution
    /// This method helps prevent "executeFetchRequest:error: A fetch request must have an entity" errors
    static func safeCatalogItemFetchRequest(in context: NSManagedObjectContext) -> NSFetchRequest<CatalogItem>? {
        return PersistenceController.createCatalogItemFetchRequest(in: context)
    }
    
    /// Creates a safe CatalogItem instance with proper entity resolution
    static func safeCatalogItemCreation(in context: NSManagedObjectContext) -> CatalogItem? {
        return PersistenceController.createCatalogItem(in: context)
    }
    
    // MARK: - Generic Entity Helpers
    
    /// Creates a safe fetch request for any entity type with explicit entity resolution
    /// Use this for other entities in your data model
    static func safeFetchRequest<T: NSManagedObject>(
        for entityName: String,
        in context: NSManagedObjectContext,
        type: T.Type
    ) -> NSFetchRequest<T>? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            log.error("Could not find entity '\(entityName)' in managed object model")
            return nil
        }
        
        let fetchRequest = NSFetchRequest<T>()
        fetchRequest.entity = entity
        fetchRequest.includesSubentities = false
        return fetchRequest
    }
    
    /// Safely creates any managed object with explicit entity resolution
    static func safeEntityCreation<T: NSManagedObject>(
        entityName: String,
        in context: NSManagedObjectContext,
        type: T.Type
    ) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            log.error("Could not create \(entityName) - entity not found in managed object model")
            return nil
        }
        
        return T(entity: entity, insertInto: context)
    }
    
    // MARK: - Entity Validation
    
    /// Validates that an entity exists in the managed object model
    static func validateEntity(_ entityName: String, in context: NSManagedObjectContext) -> Bool {
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)
        if entity == nil {
            log.error("Entity '\(entityName)' not found in managed object model")
            return false
        }
        
        log.debug("Entity '\(entityName)' validated successfully")
        return true
    }
    
    // MARK: - Common Usage Patterns
    
    /// Example of safe catalog item fetching with search
    static func fetchCatalogItems(
        matching searchText: String? = nil,
        in context: NSManagedObjectContext
    ) -> [CatalogItem] {
        guard let fetchRequest = safeCatalogItemFetchRequest(in: context) else {
            log.error("Failed to create safe fetch request for CatalogItem")
            return []
        }
        
        // Add search predicate if provided
        if let searchText = searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@ OR code CONTAINS[cd] %@ OR manufacturer CONTAINS[cd] %@", 
                                            searchText, searchText, searchText)
            fetchRequest.predicate = searchPredicate
        }
        
        // Add default sorting
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)
        ]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            log.error("Error fetching CatalogItems: \(error)")
            return []
        }
    }
    
    /// Example of safe catalog item count
    static func countCatalogItems(in context: NSManagedObjectContext) -> Int {
        guard let fetchRequest = safeCatalogItemFetchRequest(in: context) else {
            log.error("Failed to create safe fetch request for CatalogItem count")
            return 0
        }
        
        fetchRequest.includesPropertyValues = false // More efficient for counting
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            log.error("Error counting CatalogItems: \(error)")
            return 0
        }
    }
}

// MARK: - Usage Guidelines

/*
 ## How to Use These Helpers
 
 ### Instead of this (unsafe):
 ```swift
 let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
 let items = try context.fetch(fetchRequest)
 
 let newItem = CatalogItem(context: context)
 ```
 
 ### Use this (safe):
 ```swift
 let items = CoreDataEntityHelpers.fetchCatalogItems(in: context)
 
 guard let newItem = CoreDataEntityHelpers.safeCatalogItemCreation(in: context) else {
     // Handle entity creation failure
     return
 }
 ```
 
 ### For custom fetch requests:
 ```swift
 guard let fetchRequest = CoreDataEntityHelpers.safeCatalogItemFetchRequest(in: context) else {
     // Handle entity resolution failure
     return
 }
 
 // Now customize your fetch request safely
 fetchRequest.predicate = NSPredicate(format: "manufacturer == %@", "Effetre")
 fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
 
 let items = try context.fetch(fetchRequest)
 ```
 
 ### For other entities (extend as needed):
 ```swift
 guard let fetchRequest = CoreDataEntityHelpers.safeFetchRequest(
     for: "YourEntityName",
     in: context,
     type: YourEntity.self
 ) else {
     // Handle entity resolution failure
     return
 }
 ```
*/