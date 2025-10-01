//
//  CatalogItemManager.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import CoreData
import OSLog

/// Manages Core Data operations specifically for CatalogItem entities
class CatalogItemManager {
    private let log = Logger.dataLoading
    
    // MARK: - Core Data Item Creation and Management
    
    /// Central method to create a new CatalogItem from JSON data
    func createCatalogItem(from data: CatalogItemData, in context: NSManagedObjectContext) -> CatalogItem {
        let newItem = CatalogItem(context: context)
        updateCatalogItemAttributes(newItem, with: data)
        return newItem
    }
    
    /// Central method to update CatalogItem attributes
    /// Used by both creation and update operations to eliminate duplication
    func updateCatalogItemAttributes(_ item: CatalogItem, with data: CatalogItemData) {
        // Update basic attributes
        item.code = data.code
        item.name = data.name
        item.manufacturer = data.manufacturer ?? "Unknown"
        item.start_date = data.start_date ?? Date()
        item.end_date = data.end_date
        
        // Set optional attributes using centralized helper
        CoreDataHelpers.setAttributeIfExists(item, key: "id", value: data.id)
        CoreDataHelpers.setAttributeIfExists(item, key: "manufacturer_description", value: data.manufacturer_description)
        
        // Handle tags - convert array to comma-separated string + manufacturer tag
        let tagsString = createTagsString(from: data)
        CoreDataHelpers.setAttributeIfExists(item, key: "tags", value: tagsString.isEmpty ? nil : tagsString)
        
        // Handle optional attributes using helper method
        CoreDataHelpers.setAttributeIfExists(item, key: "image_path", value: data.image_path)
        CoreDataHelpers.setAttributeIfExists(item, key: "synonyms", value: CoreDataHelpers.joinStringArray(data.synonyms))
        CoreDataHelpers.setAttributeIfExists(item, key: "coe", value: data.coe)
    }
    
    /// Check if an existing item should be updated with new data - checks ALL attributes
    func shouldUpdateExistingItem(_ existing: CatalogItem, with new: CatalogItemData) -> Bool {
        // Define all attribute changes using the helper method
        let changes: [(String, Bool, String, String)] = [
            ("ID", CoreDataHelpers.attributeChanged(existing, key: "id", newValue: new.id), 
             CoreDataHelpers.getAttributeValue(existing, key: "id", defaultValue: "nil"), new.id ?? "nil"),
            ("Name", existing.name != new.name, existing.name ?? "nil", new.name),
            ("Manufacturer", existing.manufacturer != new.manufacturer, existing.manufacturer ?? "nil", new.manufacturer ?? "nil"),
            ("Manufacturer Description", CoreDataHelpers.attributeChanged(existing, key: "manufacturer_description", newValue: new.manufacturer_description),
             CoreDataHelpers.getAttributeValue(existing, key: "manufacturer_description", defaultValue: "nil"), new.manufacturer_description ?? "nil"),
            ("Tags", tagsChanged(existing: existing, new: new.tags),
             CoreDataHelpers.getAttributeValue(existing, key: "tags", defaultValue: ""), new.tags?.joined(separator: ",") ?? ""),
            ("Start Date", new.start_date != nil && existing.start_date != new.start_date,
             existing.start_date?.description ?? "nil", new.start_date?.description ?? "nil"),
            ("End Date", new.end_date != nil && existing.end_date != new.end_date,
             existing.end_date?.description ?? "nil", new.end_date?.description ?? "nil"),
            ("Image Path", CoreDataHelpers.attributeChanged(existing, key: "image_path", newValue: new.image_path),
             CoreDataHelpers.getAttributeValue(existing, key: "image_path", defaultValue: "nil"), new.image_path ?? "nil"),
            ("Synonyms", synonymsChanged(existing: existing, new: new.synonyms),
             CoreDataHelpers.getAttributeValue(existing, key: "synonyms", defaultValue: ""), new.synonyms?.joined(separator: ",") ?? ""),
            ("COE", CoreDataHelpers.attributeChanged(existing, key: "coe", newValue: new.coe),
             CoreDataHelpers.getAttributeValue(existing, key: "coe", defaultValue: "nil"), new.coe ?? "nil")
        ]
        
        let shouldUpdate = changes.contains { $0.1 } // Check if any change flag is true
        
        if shouldUpdate {
            logChanges(for: new, existing: existing, changes: changes)
        } else {
            log.info("No changes for \(new.code) - skipping update")
        }
        
        return shouldUpdate
    }
    
    /// Update an existing CatalogItem with ALL new data from JSON
    func updateCatalogItem(_ item: CatalogItem, with data: CatalogItemData) {
        updateCatalogItemAttributes(item, with: data)
    }
    
    /// Fetches existing catalog items organized by code for efficient lookup
    func fetchExistingItemsByCode(from context: NSManagedObjectContext) throws -> [String: CatalogItem] {
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingItems = try context.fetch(fetchRequest)
        
        var existingItemsByCode = [String: CatalogItem]()
        for item in existingItems {
            if let code = item.code {
                existingItemsByCode[code] = item
            }
        }
        
        log.info("Found \(existingItems.count) existing items in Core Data")
        return existingItemsByCode
    }
    
    // MARK: - Private Helper Methods
    
    /// Create a tags string from CatalogItemData, excluding manufacturer as a tag
    private func createTagsString(from data: CatalogItemData) -> String {
        var allTags: [String] = []
        
        // Add existing tags from JSON
        if let tags = data.tags, !tags.isEmpty {
            allTags.append(contentsOf: tags)
        }
        
        // Note: Manufacturer is no longer automatically added as a tag
        // The manufacturer information is stored separately in the manufacturer field
        
        return allTags.joined(separator: ",")
    }
    
    /// Check if tags have changed (including manufacturer tag)
    private func tagsChanged(existing: CatalogItem, new: [String]?) -> Bool {
        let existingTagsString = CoreDataHelpers.getAttributeValue(existing, key: "tags", defaultValue: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the expected new tags string using our helper method
        let tempData = CatalogItemData(
            id: CoreDataHelpers.getAttributeValue(existing, key: "id", defaultValue: nil),
            code: existing.code ?? "",
            manufacturer: existing.manufacturer,
            name: existing.name ?? "",
            start_date: existing.start_date,
            end_date: existing.end_date,
            manufacturer_description: CoreDataHelpers.getAttributeValue(existing, key: "manufacturer_description", defaultValue: nil),
            synonyms: [],
            tags: new,
            image_path: CoreDataHelpers.getAttributeValue(existing, key: "image_path", defaultValue: nil),
            coe: CoreDataHelpers.getAttributeValue(existing, key: "coe", defaultValue: nil)
        )
        
        let newTagsString = createTagsString(from: tempData).trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTagsString != newTagsString
    }
    
    /// Check if synonyms have changed
    private func synonymsChanged(existing: CatalogItem, new: [String]?) -> Bool {
        let existingSynonymsString = CoreDataHelpers.getAttributeValue(existing, key: "synonyms", defaultValue: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newSynonymsString = (new?.joined(separator: ",") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return existingSynonymsString != newSynonymsString
    }
    
    /// Logs detailed change information for debugging
    private func logChanges(for new: CatalogItemData, existing: CatalogItem, changes: [(String, Bool, String, String)]) {
        log.debug("Changes detected for \(new.code):")
        for (field, hasChanged, oldValue, newValue) in changes {
            if hasChanged {
                log.debug("   \(field): '\(oldValue)' -> '\(newValue)'")
            }
        }
    }
}
