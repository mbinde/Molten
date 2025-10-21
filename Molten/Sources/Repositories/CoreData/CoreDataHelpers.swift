//
//  CoreDataHelpers.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
@preconcurrency import CoreData

/// Shared utilities for Core Data operations and string processing
struct CoreDataHelpers {
    
    // MARK: - Safe Core Data Value Extraction
    
    /// Safely extracts a string value from a Core Data entity, handling missing attributes
    static func safeStringValue(from entity: NSManagedObject, key: String) -> String {
        // Ensure we're on the correct queue and the entity is valid
        guard !entity.isFault else {
            print("⚠️ Entity is a fault when accessing key '\(key)'")
            return ""
        }
        
        guard !entity.isDeleted else {
            print("⚠️ Entity is deleted when accessing key '\(key)'")
            return ""
        }
        
        let entityDescription = entity.entity
        
        guard entityDescription.attributesByName[key] != nil else {
            return ""
        }
        
        // Use performAndWait for thread safety if needed
        if let context = entity.managedObjectContext {
            var result: String = ""
            context.performAndWait {
                result = (entity.value(forKey: key) as? String) ?? ""
            }
            return result
        } else {
            // If no context, try direct access (but this is risky)
            return (entity.value(forKey: key) as? String) ?? ""
        }
    }
    
    /// Safely extracts a string array from a comma-separated Core Data string attribute
    static func safeStringArray(from entity: NSManagedObject, key: String) -> [String] {
        // Use the improved safeStringValue which handles thread safety and entity validation
        let stringValue = safeStringValue(from: entity, key: key)
        guard !stringValue.isEmpty else { return [] }
        
        return stringValue
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// Creates a comma-separated string from an array, filtering empty values
    static func joinStringArray(_ array: [String]?) -> String {
        guard let array = array else { return "" }
        return array
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
    
    // MARK: - Core Data Attribute Management
    
    /// Check if a Core Data entity has a specific attribute
    static func hasAttribute(_ entity: NSManagedObject, key: String) -> Bool {
        // Check if entity is valid first
        guard !entity.isFault, !entity.isDeleted else {
            return false
        }
        
        return entity.entity.attributesByName[key] != nil
    }
    
    /// Safely set a Core Data attribute if it exists in the entity
    static func setAttributeIfExists(_ entity: NSManagedObject, key: String, value: Any?) {
        // Validate entity state first
        guard !entity.isFault, !entity.isDeleted else {
            print("⚠️ Cannot set attribute '\(key)' on invalid entity")
            return
        }
        
        guard hasAttribute(entity, key: key) else { 
            print("⚠️ Attribute '\(key)' does not exist on entity \(entity.entity.name ?? "unknown")")
            return 
        }
        
        // Use context's performAndWait for thread safety
        if let context = entity.managedObjectContext {
            context.performAndWait {
                entity.setValue(value, forKey: key)
            }
        } else {
            entity.setValue(value, forKey: key)
        }
    }
    
    /// Safely get a value from Core Data attribute with fallback
    static func getAttributeValue<T>(_ entity: NSManagedObject, key: String, defaultValue: T) -> T {
        // Check entity validity first
        guard !entity.isFault, !entity.isDeleted else {
            return defaultValue
        }
        
        guard hasAttribute(entity, key: key) else { 
            return defaultValue 
        }
        
        // Use context's performAndWait for thread safety
        if let context = entity.managedObjectContext {
            var result: T = defaultValue
            context.performAndWait {
                result = (entity.value(forKey: key) as? T) ?? defaultValue
            }
            return result
        } else {
            return (entity.value(forKey: key) as? T) ?? defaultValue
        }
    }
    
    /// Check if two Core Data entities have different values for a given attribute
    static func attributeChanged<T: Equatable>(_ entity: NSManagedObject, key: String, newValue: T?) -> Bool {
        // Check entity validity first
        guard !entity.isFault, !entity.isDeleted else {
            return false
        }
        
        guard hasAttribute(entity, key: key) else { 
            return false 
        }
        
        // Use context's performAndWait for thread safety
        if let context = entity.managedObjectContext {
            var result: Bool = false
            context.performAndWait {
                let currentValue = entity.value(forKey: key) as? T
                result = currentValue != newValue
            }
            return result
        } else {
            let currentValue = entity.value(forKey: key) as? T
            return currentValue != newValue
        }
    }
    
    // MARK: - Core Data Entity Safety
    
    /// Validates that a Core Data entity is in a safe state for operations
    static func isEntitySafe(_ entity: NSManagedObject) -> Bool {
        return !entity.isFault && !entity.isDeleted && entity.managedObjectContext != nil
    }
    
    /// Safely fault a Core Data entity and check if it's valid
    static func safeFaultEntity(_ entity: NSManagedObject) -> Bool {
        guard !entity.isDeleted else { return false }
        
        if let context = entity.managedObjectContext {
            var isSafe = false
            context.performAndWait {
                if entity.isFault {
                    // Force fault to fire by accessing a property
                    _ = entity.objectID
                    isSafe = !entity.isFault && !entity.isDeleted
                } else {
                    isSafe = !entity.isDeleted
                }
            }
            return isSafe
        }
        return false
    }
    
    /// Safely refreshes a Core Data entity
    static func safeRefreshEntity(_ entity: NSManagedObject, mergeChanges: Bool = true) {
        guard let context = entity.managedObjectContext else { return }
        guard !entity.isDeleted else { return }
        
        context.performAndWait {
            context.refresh(entity, mergeChanges: mergeChanges)
        }
    }
    
    // MARK: - Core Data Fetch Request Helpers
    
    /// Safely creates a fetch request with proper entity configuration
    static func createSafeFetchRequest<T: NSManagedObject>(for entityName: String, in context: NSManagedObjectContext) throws -> NSFetchRequest<T> {
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        // Ensure entity is properly configured
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw NSError(domain: "CoreDataHelpers", code: 1004, userInfo: [
                NSLocalizedDescriptionKey: "Could not find \(entityName) entity in context"
            ])
        }
        fetchRequest.entity = entity
        return fetchRequest
    }
    
    // MARK: - Safe Collection Operations
    
    /// Safely enumerates a Core Data collection to prevent "Collection was mutated while being enumerated" errors
    static func safelyEnumerate<T>(_ collection: Set<T>, operation: (T) -> Void) {
        // Create a snapshot of the collection to prevent mutation during enumeration
        let snapshot = Array(collection)
        for item in snapshot {
            operation(item)
        }
    }
    
    /// Safely enumerates a Core Data NSSet to prevent mutation during enumeration
    static func safelyEnumerate(_ nsSet: NSSet, operation: (Any) -> Void) {
        // Create a snapshot of the NSSet to prevent mutation during enumeration
        let snapshot = nsSet.allObjects
        for item in snapshot {
            operation(item)
        }
    }
    
    // MARK: - Core Data Saving
    
    /// Safe Core Data save with error logging and store validation
    static func safeSave(context: NSManagedObjectContext, description: String) throws {
        // Validate context state
        guard let coordinator = context.persistentStoreCoordinator else {
            let error = NSError(domain: "CoreDataHelpers", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent store coordinator"
            ])
            throw error
        }
        
        // Check if stores are properly loaded
        guard !coordinator.persistentStores.isEmpty else {
            let error = NSError(domain: "CoreDataHelpers", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent stores loaded - check PersistenceController initialization"
            ])
            throw error
        }
        
        // Check if context has changes to avoid unnecessary saves
        guard context.hasChanges else {
            print("ℹ️ No changes to save for \(description)")
            return
        }
        
        // Perform the save within the context's queue for thread safety
        var saveError: Error?
        context.performAndWait {
            do {
                // Validate objects before saving
                for object in context.insertedObjects {
                    do {
                        try object.validateForInsert()
                    } catch {
                        saveError = error
                        return
                    }
                }
                
                for object in context.updatedObjects {
                    do {
                        try object.validateForUpdate()
                    } catch {
                        saveError = error
                        return
                    }
                }
                
                for object in context.deletedObjects {
                    do {
                        try object.validateForDelete()
                    } catch {
                        saveError = error
                        return
                    }
                }
                
                // Perform the actual save
                try context.save()
                print("✅ \(description) saved successfully")
            } catch let error as NSError {
                print("❌ Error saving \(description): \(error)")
                print("   Domain: \(error.domain)")
                print("   Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                
                if let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    print("🔍 Validation errors:")
                    for (index, validationError) in validationErrors.enumerated() {
                        print("     Error \(index + 1): \(validationError.localizedDescription)")
                        
                        // Print additional context for validation errors
                        if let failedObject = validationError.userInfo[NSValidationObjectErrorKey] as? NSManagedObject {
                            print("       Failed object: \(failedObject.entity.name ?? "Unknown")")
                        }
                        if let failedKey = validationError.userInfo[NSValidationKeyErrorKey] as? String {
                            print("       Failed key: \(failedKey)")
                        }
                    }
                }
                
                saveError = error
            }
        }
        
        // Re-throw any error that occurred during the save
        if let error = saveError {
            throw error
        }
    }
}

/// Protocol for entities that have displayable titles
protocol DisplayableEntity {
    var id: String? { get }
    var catalog_code: String? { get }
}

/// Extension providing consistent display title logic
extension DisplayableEntity {
    var displayTitle: String {
        if let catalogCode = catalog_code, !catalogCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return catalogCode
        } else if let id = id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))"
        } else {
            return "Untitled Item"
        }
    }
}

/// Protocol for entities with inventory-related data
protocol InventoryDataEntity {
    var count: Double { get }
    var units: Int16 { get }
    var notes: String? { get }
    var type: Int16 { get }
}
