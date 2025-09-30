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
        
        let entityDescription = item.entity
        
        // Set ID if available
        if let id = data.id {
            if entityDescription.attributesByName["id"] != nil {
                item.setValue(id, forKey: "id")
            }
        }
        
        // Set manufacturer_description if available and attribute exists
        if entityDescription.attributesByName["manufacturer_description"] != nil {
            item.setValue(data.manufacturer_description, forKey: "manufacturer_description")
        }
        
        // Handle tags - convert array to comma-separated string + manufacturer tag
        let tagsString = createTagsString(from: data)
        setAttributeIfExists(item, key: "tags", value: tagsString.isEmpty ? nil : tagsString)
        
        // Handle optional attributes using helper method
        setAttributeIfExists(item, key: "image_path", value: data.image_path)
        setAttributeIfExists(item, key: "synonyms", value: CoreDataHelpers.joinStringArray(data.synonyms))
        setAttributeIfExists(item, key: "coe", value: data.coe)
    }
    
    /// Check if an existing item should be updated with new data - checks ALL attributes
    func shouldUpdateExistingItem(_ existing: CatalogItem, with new: CatalogItemData) -> Bool {
        // Check all possible attribute changes
        let idChanged = (existing.value(forKey: "id") as? String) != new.id
        let nameChanged = existing.name != new.name
        let manufacturerChanged = existing.manufacturer != new.manufacturer
        let tagsChanged = self.tagsChanged(existing: existing, new: new.tags)
        
        // Check manufacturer_description if it exists in the Core Data model
        let manufacturerDescriptionChanged: Bool
        let entityDescription = existing.entity
        if entityDescription.attributesByName["manufacturer_description"] != nil {
            let existingManufacturerDescription = existing.value(forKey: "manufacturer_description") as? String
            manufacturerDescriptionChanged = existingManufacturerDescription != new.manufacturer_description
        } else {
            manufacturerDescriptionChanged = false
        }
        
        // Check image_path if it exists in the Core Data model
        let imagePathChanged: Bool
        if entityDescription.attributesByName["image_path"] != nil {
            let existingImagePath = existing.value(forKey: "image_path") as? String
            imagePathChanged = existingImagePath != new.image_path
        } else {
            imagePathChanged = false
        }
        
        // Check synonyms if it exists in the Core Data model
        let synonymsChanged: Bool
        if entityDescription.attributesByName["synonyms"] != nil {
            synonymsChanged = self.synonymsChanged(existing: existing, new: new.synonyms)
        } else {
            synonymsChanged = false
        }
        
        // Check COE if it exists in the Core Data model
        let coeChanged: Bool
        if entityDescription.attributesByName["coe"] != nil {
            let existingCoe = existing.value(forKey: "coe") as? String
            coeChanged = existingCoe != new.coe
        } else {
            coeChanged = false
        }
        
        // Check date changes (only if new dates are provided and different)
        let startDateChanged = new.start_date != nil && existing.start_date != new.start_date
        let endDateChanged = new.end_date != nil && existing.end_date != new.end_date
        
        let shouldUpdate = idChanged || nameChanged || manufacturerChanged || tagsChanged || startDateChanged || endDateChanged || manufacturerDescriptionChanged || imagePathChanged || synonymsChanged || coeChanged
        
        if shouldUpdate {
            logChanges(for: new, existing: existing, changes: [
                ("ID", idChanged, existing.value(forKey: "id") as? String ?? "nil", new.id ?? "nil"),
                ("Name", nameChanged, existing.name ?? "nil", new.name),
                ("Manufacturer", manufacturerChanged, existing.manufacturer ?? "nil", new.manufacturer ?? "nil"),
                ("Manufacturer Description", manufacturerDescriptionChanged, existing.value(forKey: "manufacturer_description") as? String ?? "nil", new.manufacturer_description ?? "nil"),
                ("Tags", tagsChanged, existing.value(forKey: "tags") as? String ?? "", new.tags?.joined(separator: ",") ?? ""),
                ("Start Date", startDateChanged, existing.start_date?.description ?? "nil", new.start_date?.description ?? "nil"),
                ("End Date", endDateChanged, existing.end_date?.description ?? "nil", new.end_date?.description ?? "nil"),
                ("Image Path", imagePathChanged, existing.value(forKey: "image_path") as? String ?? "nil", new.image_path ?? "nil"),
                ("Synonyms", synonymsChanged, existing.value(forKey: "synonyms") as? String ?? "", new.synonyms?.joined(separator: ",") ?? ""),
                ("COE", coeChanged, existing.value(forKey: "coe") as? String ?? "nil", new.coe ?? "nil")
            ])
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
    
    /// Safe method to set Core Data attribute if it exists in the entity
    private func setAttributeIfExists(_ item: CatalogItem, key: String, value: String?) {
        let entityDescription = item.entity
        guard entityDescription.attributesByName[key] != nil else { return }
        item.setValue(value, forKey: key)
    }
    
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
        let existingTagsString = (existing.value(forKey: "tags") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the expected new tags string using our helper method
        let tempData = CatalogItemData(
            id: existing.value(forKey: "id") as? String,
            code: existing.code ?? "",
            manufacturer: existing.manufacturer,
            name: existing.name ?? "",
            start_date: existing.start_date,
            end_date: existing.end_date,
            manufacturer_description: existing.value(forKey: "manufacturer_description") as? String,
            synonyms: [],
            tags: new,
            image_path: existing.value(forKey: "image_path") as? String,
            coe: existing.value(forKey: "coe") as? String
        )
        
        let newTagsString = createTagsString(from: tempData).trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTagsString != newTagsString
    }
    
    /// Check if synonyms have changed
    private func synonymsChanged(existing: CatalogItem, new: [String]?) -> Bool {
        let existingSynonymsString = (existing.value(forKey: "synonyms") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
