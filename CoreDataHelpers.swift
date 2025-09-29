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
    var custom_tags: String? { get }
}

/// Extension providing consistent display title logic
extension DisplayableEntity {
    var displayTitle: String {
        if let tags = custom_tags, !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tags
        } else if let id = id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))"
        } else {
            return "Untitled Item"
        }
    }
}

/// Protocol for entities with inventory-related data
protocol InventoryDataEntity {
    var inventory_amount: String? { get }
    var inventory_units: String? { get }
    var inventory_notes: String? { get }
    var shopping_amount: String? { get }
    var shopping_units: String? { get }
    var shopping_notes: String? { get }
    var forsale_amount: String? { get }
    var forsale_units: String? { get }
    var forsale_notes: String? { get }
}

/// Extension providing consistent inventory status checking
extension InventoryDataEntity {
    var hasInventory: Bool {
        hasNonEmptyValue(inventory_amount) || hasNonEmptyValue(inventory_notes)
    }
    
    var needsShopping: Bool {
        hasNonEmptyValue(shopping_amount) || hasNonEmptyValue(shopping_notes)
    }
    
    var isForSale: Bool {
        hasNonEmptyValue(forsale_amount) || hasNonEmptyValue(forsale_notes)
    }
    
    var hasAnyInventoryData: Bool {
        hasInventory || needsShopping || isForSale || hasNonEmptyValue(custom_tags)
    }
    
    private func hasNonEmptyValue(_ value: String?) -> Bool {
        guard let value = value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var custom_tags: String? {
        // This should be implemented by conforming types if they have custom_tags
        return nil
    }
}