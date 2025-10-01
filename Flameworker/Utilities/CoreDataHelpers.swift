//
//  CoreDataHelpers.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import CoreData

/// Shared utilities for Core Data operations and string processing
struct CoreDataHelpers {
    
    // MARK: - Safe Core Data Value Extraction
    
    /// Safely extracts a string value from a Core Data entity, handling missing attributes
    static func safeStringValue(from entity: NSManagedObject, key: String) -> String {
        let entityDescription = entity.entity
        
        guard entityDescription.attributesByName[key] != nil else {
            return ""
        }
        
        do {
            return (entity.value(forKey: key) as? String) ?? ""
        } catch {
            print("⚠️ Error accessing key '\(key)' on entity \(entityDescription.name ?? "unknown"): \(error)")
            return ""
        }
    }
    
    /// Safely extracts a string array from a comma-separated Core Data string attribute
    static func safeStringArray(from entity: NSManagedObject, key: String) -> [String] {
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
        return entity.entity.attributesByName[key] != nil
    }
    
    /// Safely set a Core Data attribute if it exists in the entity
    static func setAttributeIfExists(_ entity: NSManagedObject, key: String, value: Any?) {
        guard hasAttribute(entity, key: key) else { return }
        entity.setValue(value, forKey: key)
    }
    
    /// Safely get a value from Core Data attribute with fallback
    static func getAttributeValue<T>(_ entity: NSManagedObject, key: String, defaultValue: T) -> T {
        guard hasAttribute(entity, key: key) else { return defaultValue }
        return (entity.value(forKey: key) as? T) ?? defaultValue
    }
    
    /// Check if two Core Data entities have different values for a given attribute
    static func attributeChanged<T: Equatable>(_ entity: NSManagedObject, key: String, newValue: T?) -> Bool {
        guard hasAttribute(entity, key: key) else { return false }
        let currentValue = entity.value(forKey: key) as? T
        return currentValue != newValue
    }
    
    // MARK: - Core Data Saving
    
    /// Safe Core Data save with error logging
    static func safeSave(context: NSManagedObjectContext, description: String) throws {
        do {
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
                }
            }
            
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