//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import Foundation
import CoreData

class DataLoadingService {
    static let shared = DataLoadingService()
    
    private init() {}
    
    func loadCatalogItemsFromJSON(into context: NSManagedObjectContext) async throws {
        print("🔍 DataLoadingService: Starting JSON load process...")
        
        // First, let's debug what's in the bundle
        if let bundlePath = Bundle.main.resourcePath {
            print("📁 Bundle path: \(bundlePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                let jsonFiles = contents.filter { $0.hasSuffix(".json") }
                print("📄 JSON files in bundle: \(jsonFiles)")
            } catch {
                print("❌ Error reading bundle contents: \(error)")
            }
        }
        
        // Loading JSON file from app bundle root
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("❌ Could not find URL for colors.json in bundle")
            throw DataLoadingError.fileNotFound("Could not find colors.json in bundle")
        }
        
        print("✅ Found colors.json at: \(url)")
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not load data from colors.json")
            throw DataLoadingError.fileNotFound("Could not load data from colors.json")
        }
        
        print("✅ Successfully loaded data, size: \(data.count) bytes")
        
        // Check if items already exist to avoid duplicates
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCatalogItemsCount = try context.count(for: fetchRequest)
        /*
        guard existingCatalogItemsCount == 0 else {
            print("⚠️ CatalogItems already exist in Core Data (\(existingCatalogItemsCount) items), skipping JSON load")
            return
        }
         */
        
        // Fall back to standard JSON parsing
        let decoder = JSONDecoder()
        
        // Configure multiple date decoding strategies to try
        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]
        
        // First, try to decode as a nested structure with "colors" key
        do {
            let wrappedData = try decoder.decode(WrappedColorsData.self, from: data)
            print("✅ Successfully decoded \(wrappedData.colors.count) items from nested JSON structure")
            try await processArray(wrappedData.colors, context: context)
            return
        } catch {
            print("⚠️ Failed to decode as nested structure: \(error)")
        }
        
        // If nested structure failed, try the original approaches
        // First, let's try to decode as dictionary
        do {
            // Try different date formats
            for dateFormat in possibleDateFormats {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                do {
                    let jsonDictionary = try decoder.decode([String: CatalogItemData].self, from: data)
                    print("✅ Successfully decoded \(jsonDictionary.count) items from JSON dictionary using date format: \(dateFormat)")
                    
                    // Process the dictionary
                    try await processDictionary(jsonDictionary, context: context)
                    return
                } catch {
                    print("⚠️ Failed to decode as dictionary with date format \(dateFormat): \(error)")
                    continue
                }
            }
            
            // If dictionary failed, try as array
            print("🔄 Dictionary decoding failed, trying as array...")
            for dateFormat in possibleDateFormats {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                do {
                    let jsonArray = try decoder.decode([CatalogItemData].self, from: data)
                    print("✅ Successfully decoded \(jsonArray.count) items from JSON array using date format: \(dateFormat)")
                    
                    // Process the array
                    try await processArray(jsonArray, context: context)
                    return
                } catch {
                    print("⚠️ Failed to decode as array with date format \(dateFormat): \(error)")
                    continue
                }
            }
            
            // If both failed, try without date formatting
            print("🔄 Trying to decode without date formatting...")
            decoder.dateDecodingStrategy = .deferredToDate
            
            do {
                let jsonDictionary = try decoder.decode([String: CatalogItemData].self, from: data)
                print("✅ Successfully decoded \(jsonDictionary.count) items from JSON dictionary without date formatting")
                try await processDictionary(jsonDictionary, context: context)
                return
            } catch {
                print("⚠️ Failed to decode as dictionary without date formatting: \(error)")
            }
            
            do {
                let jsonArray = try decoder.decode([CatalogItemData].self, from: data)
                print("✅ Successfully decoded \(jsonArray.count) items from JSON array without date formatting")
                try await processArray(jsonArray, context: context)
                return
            } catch {
                print("⚠️ Failed to decode as array without date formatting: \(error)")
            }
            
            throw DataLoadingError.decodingFailed("Could not decode JSON in any supported format")
            
        } catch let decodingError {
            print("❌ JSON Decoding Error: \(decodingError)")
            // Let's try to see what the JSON actually looks like
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 First 500 characters of JSON:")
                print(String(jsonString.prefix(500)))
                
                // Try to identify the JSON structure
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                    print("🔍 JSON appears to be an object/dictionary")
                } else if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
                    print("🔍 JSON appears to be an array")
                } else {
                    print("🔍 JSON structure unclear")
                }
            }
            throw DataLoadingError.decodingFailed("Failed to decode JSON: \(decodingError.localizedDescription)")
        }
    }
    
    // MARK: - Core Data Item Creation and Management
    
    /// Central method to create a new CatalogItem from JSON data
    /// This eliminates duplication across multiple loading methods
    private func createCatalogItem(from data: CatalogItemData, in context: NSManagedObjectContext) -> CatalogItem {
        let newItem = CatalogItem(context: context)
        updateCatalogItemAttributes(newItem, with: data)
        return newItem
    }
    
    /// Central method to update CatalogItem attributes
    /// Used by both creation and update operations to eliminate duplication
    private func updateCatalogItemAttributes(_ item: CatalogItem, with data: CatalogItemData) {
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
        if !tagsString.isEmpty, entityDescription.attributesByName["tags"] != nil {
            item.setValue(tagsString, forKey: "tags")
        }
        
        // Handle image_path if available and attribute exists
        if entityDescription.attributesByName["image_path"] != nil {
            item.setValue(data.image_path, forKey: "image_path")
        }
        
        // Handle synonyms if available and attribute exists
        if let synonyms = data.synonyms, !synonyms.isEmpty,
           entityDescription.attributesByName["synonyms"] != nil {
            let synonymsString = synonyms.joined(separator: ",")
            item.setValue(synonymsString, forKey: "synonyms")
        }
        
        // Handle COE if available and attribute exists
        if let coe = data.coe, !coe.isEmpty,
           entityDescription.attributesByName["coe"] != nil {
            item.setValue(coe, forKey: "coe")
        }
    }
    
    // Helper function to process dictionary data
    private func processDictionary(_ jsonDictionary: [String: CatalogItemData], context: NSManagedObjectContext) async throws {
        try await MainActor.run {
            for (index, (key, catalogItemData)) in jsonDictionary.enumerated() {
                _ = createCatalogItem(from: catalogItemData, in: context)
                
                if index < 3 { // Log first 3 items for debugging
                    print("📝 Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code)) from key: \(key)")
                }
            }
            
            do {
                try context.save()
                print("🎉 Successfully loaded \(jsonDictionary.count) items from JSON dictionary and saved to Core Data")
            } catch {
                print("❌ Error saving to Core Data: \(error)")
                throw DataLoadingError.decodingFailed("Failed to save to Core Data: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper function to process array data
    private func processArray(_ jsonArray: [CatalogItemData], context: NSManagedObjectContext) async throws {
        try await MainActor.run {
            for (index, catalogItemData) in jsonArray.enumerated() {
                _ = createCatalogItem(from: catalogItemData, in: context)
                
                if index < 3 { // Log first 3 items for debugging
                    print("📝 Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code))")
                }
            }
            
            do {
                try context.save()
                print("🎉 Successfully loaded \(jsonArray.count) items from JSON array and saved to Core Data")
            } catch {
                print("❌ Error saving to Core Data: \(error)")
                throw DataLoadingError.decodingFailed("Failed to save to Core Data: \(error.localizedDescription)")
            }
        }
    }
    func loadCatalogItemsFromJSONSync(into context: NSManagedObjectContext) throws {
        print("🔍 DataLoadingService: Starting synchronous JSON load process...")
        
        // First, let's debug what's in the bundle
        if let bundlePath = Bundle.main.resourcePath {
            print("📁 Bundle path: \(bundlePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                let jsonFiles = contents.filter { $0.hasSuffix(".json") }
                print("📄 JSON files in bundle root: \(jsonFiles)")
                
                // Also check Data subdirectory
                let dataPath = bundlePath + "/Data"
                if FileManager.default.fileExists(atPath: dataPath) {
                    let dataContents = try FileManager.default.contentsOfDirectory(atPath: dataPath)
                    let dataJsonFiles = dataContents.filter { $0.hasSuffix(".json") }
                    print("📄 JSON files in Data folder: \(dataJsonFiles)")
                }
            } catch {
                print("❌ Error reading bundle contents: \(error)")
            }
        }
        
        // Try multiple possible locations for the JSON file
        var url: URL?
        var data: Data?
        
        // First try: root of bundle
        if let rootUrl = Bundle.main.url(forResource: "colors", withExtension: "json") {
            print("✅ Found colors.json in bundle root")
            url = rootUrl
        }
        // Second try: Data subdirectory
        else if let dataUrl = Bundle.main.url(forResource: "Data/colors", withExtension: "json") {
            print("✅ Found colors.json in Data subdirectory")
            url = dataUrl
        }
        // Third try: effetre name in root
        else if let efferreUrl = Bundle.main.url(forResource: "effetre", withExtension: "json") {
            print("✅ Found effetre.json in bundle root")
            url = efferreUrl
        }
        // Fourth try: effetre name in Data subdirectory
        else if let efferreDataUrl = Bundle.main.url(forResource: "Data/effetre", withExtension: "json") {
            print("✅ Found effetre.json in Data subdirectory")
            url = efferreDataUrl
        }
        
        guard let jsonUrl = url else {
            print("❌ Could not find colors.json or effetre.json in any location")
            throw DataLoadingError.fileNotFound("Could not find colors.json or effetre.json in bundle")
        }
        
        guard let jsonData = try? Data(contentsOf: jsonUrl) else {
            print("❌ Could not load data from JSON file")
            throw DataLoadingError.fileNotFound("Could not load data from JSON file")
        }
        
        print("✅ Successfully loaded JSON data, size: \(jsonData.count) bytes")
        
        // Check if items already exist to avoid duplicates
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCatalogItemsCount = try context.count(for: fetchRequest)
        /*
        guard existingCatalogItemsCount == 0 else {
            print("⚠️ CatalogItems already exist in Core Data (\(existingCatalogItemsCount) items), skipping JSON load")
            return
        }
         */
        
        // Fall back to standard JSON parsing
        let decoder = JSONDecoder()
        
        // Try the nested structure first (like the async method)
        do {
            let wrappedData = try decoder.decode(WrappedColorsData.self, from: jsonData)
            print("✅ Successfully decoded \(wrappedData.colors.count) items from nested JSON structure")
            
            for catalogItemData in wrappedData.colors {
                _ = createCatalogItem(from: catalogItemData, in: context)
            }
            
            try context.save()
            print("🎉 Successfully loaded \(wrappedData.colors.count) items from nested JSON structure and saved to Core Data")
            return
        } catch {
            print("⚠️ Failed to decode as nested structure: \(error)")
        }
        
        // Fall back to dictionary format
        do {
            let jsonDictionary = try decoder.decode([String: CatalogItemData].self, from: jsonData)
            print("✅ Successfully decoded \(jsonDictionary.count) items from JSON dictionary")
            
            for (_, catalogItemData) in jsonDictionary {
                _ = createCatalogItem(from: catalogItemData, in: context)
            }
            
            try context.save()
            print("🎉 Successfully loaded \(jsonDictionary.count) items from JSON dictionary and saved to Core Data")
        } catch {
            print("❌ Failed to decode as dictionary: \(error)")
            throw DataLoadingError.decodingFailed("Failed to decode JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Smart Merge Functionality
    
    /// Load JSON with comprehensive attribute merging - updates ALL changed attributes
    func loadCatalogItemsFromJSONWithMerge(into context: NSManagedObjectContext) async throws {
        print("🔍 DataLoadingService: Starting comprehensive JSON merge...")
        
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw DataLoadingError.fileNotFound("Could not find or load colors.json")
        }
        
        // Parse standard JSON data
        let wrappedData: WrappedColorsData
        let decoder = JSONDecoder()
        wrappedData = try decoder.decode(WrappedColorsData.self, from: data)
        print("✅ Parsed \(wrappedData.colors.count) items from standard JSON")
        
        // Create a dictionary of existing items by code for fast lookup
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingItems = try context.fetch(fetchRequest)
        var existingItemsByCode = [String: CatalogItem]()
        
        for item in existingItems {
            if let code = item.code {
                existingItemsByCode[code] = item
            }
        }
        
        print("📊 Found \(existingItems.count) existing items in Core Data")
        
        try await MainActor.run {
            var newItemsCount = 0
            var updatedItemsCount = 0
            var skippedItemsCount = 0
            
            for catalogItemData in wrappedData.colors {
                if let existingItem = existingItemsByCode[catalogItemData.code] {
                    // Item exists, check for any attribute changes
                    if shouldUpdateExistingItem(existingItem, with: catalogItemData) {
                        updateCatalogItem(existingItem, with: catalogItemData)
                        updatedItemsCount += 1
                        print("🔄 Updated: \(catalogItemData.name) (\(catalogItemData.code))")
                    } else {
                        skippedItemsCount += 1
                    }
                } else {
                    // New item, create it
                    _ = createCatalogItem(from: catalogItemData, in: context)
                    newItemsCount += 1
                    print("➕ Added: \(catalogItemData.name) (\(catalogItemData.code))")
                }
            }
            
            do {
                try context.save()
                print("🎉 Comprehensive merge complete!")
                print("   📈 \(newItemsCount) new items added")
                print("   🔄 \(updatedItemsCount) items updated") 
                print("   ⏭️ \(skippedItemsCount) items unchanged")
            } catch let error as NSError {
                print("❌ Error saving comprehensive merge: \(error)")
                print("💡 Error details:")
                print("   Domain: \(error.domain)")
                print("   Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                
                // Check for validation errors
                if let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    print("🔍 Validation errors found:")
                    for (index, validationError) in validationErrors.enumerated() {
                        print("   Error \(index + 1):")
                        print("     Description: \(validationError.localizedDescription)")
                        print("     User Info: \(validationError.userInfo)")
                        
                        // Check for specific validation keys
                        if let validationKey = validationError.userInfo[NSValidationKeyErrorKey] as? String {
                            print("     Invalid Key: \(validationKey)")
                        }
                        if let validationObject = validationError.userInfo[NSValidationObjectErrorKey] {
                            print("     Object: \(validationObject)")
                        }
                    }
                } else {
                    print("🔍 Error user info: \(error.userInfo)")
                }
                
                throw DataLoadingError.decodingFailed("Failed to save comprehensive merge: \(error.localizedDescription)")
            }
        }
    }
    
    /// Load JSON only if database is empty (safest approach)
    func loadCatalogItemsFromJSONIfEmpty(into context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCount = try context.count(for: fetchRequest)
        
        if existingCount == 0 {
            print("📂 Database is empty, loading JSON data...")
            try await loadCatalogItemsFromJSON(into: context)
        } else {
            print("⚠️ Database contains \(existingCount) items, skipping JSON load")
            print("💡 Use 'Reset' button first if you want to reload from JSON")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if an existing item should be updated with new data - checks ALL attributes
    private func shouldUpdateExistingItem(_ existing: CatalogItem, with new: CatalogItemData) -> Bool {
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
            print("🔍 Changes detected for \(new.code):")
            if idChanged { 
                let oldId = existing.value(forKey: "id") as? String ?? "nil"
                print("   ID: '\(oldId)' -> '\(new.id ?? "nil")'") 
            }
            if nameChanged { print("   Name: '\(existing.name ?? "nil")' -> '\(new.name)'") }
            if manufacturerChanged { print("   Manufacturer: '\(existing.manufacturer ?? "nil")' -> '\(new.manufacturer ?? "nil")'") }
            if manufacturerDescriptionChanged { 
                let oldDesc = existing.value(forKey: "manufacturer_description") as? String ?? "nil"
                print("   Manufacturer Description: '\(oldDesc)' -> '\(new.manufacturer_description ?? "nil")'") 
            }
            if tagsChanged {
                let oldTags = existing.value(forKey: "tags") as? String ?? ""
                let newTags = new.tags?.joined(separator: ",") ?? ""
                print("   Tags: '\(oldTags)' -> '\(newTags)'") 
            }
            if startDateChanged {
                let oldDate = existing.start_date?.description ?? "nil"
                let newDate = new.start_date?.description ?? "nil"
                print("   Start Date: '\(oldDate)' -> '\(newDate)'")
            }
            if endDateChanged {
                let oldDate = existing.end_date?.description ?? "nil"  
                let newDate = new.end_date?.description ?? "nil"
                print("   End Date: '\(oldDate)' -> '\(newDate)'")
            }
            if imagePathChanged {
                let oldImagePath = existing.value(forKey: "image_path") as? String ?? "nil"
                print("   Image Path: '\(oldImagePath)' -> '\(new.image_path ?? "nil")'")
            }
            if synonymsChanged {
                let oldSynonyms = existing.value(forKey: "synonyms") as? String ?? ""
                let newSynonyms = new.synonyms?.joined(separator: ",") ?? ""
                print("   Synonyms: '\(oldSynonyms)' -> '\(newSynonyms)'")
            }
            if coeChanged {
                let oldCoe = existing.value(forKey: "coe") as? String ?? "nil"
                print("   COE: '\(oldCoe)' -> '\(new.coe ?? "nil")'")
            }
        } else {
            print("✅ No changes for \(new.code) - skipping update")
        }
        
        return shouldUpdate
    }
    
    /// Check if tags have changed (including manufacturer tag)
    private func tagsChanged(existing: CatalogItem, new: [String]?) -> Bool {
        let existingTagsString = (existing.value(forKey: "tags") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the expected new tags string using our helper method
        // We need to create a temporary CatalogItemData to use our helper
        let tempData = CatalogItemData(
            id: existing.value(forKey: "id") as? String,
            code: existing.code ?? "",
            manufacturer: existing.manufacturer,
            name: existing.name ?? "",
            start_date: existing.start_date,
            end_date: existing.end_date,
            manufacturer_description: existing.value(forKey: "manufacturer_description") as? String,
            synonyms: new, // This doesn't matter for tags comparison
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
    
    /// Update an existing CatalogItem with ALL new data from JSON
    private func updateCatalogItem(_ item: CatalogItem, with data: CatalogItemData) {
        // Use our centralized attribute updating logic
        updateCatalogItemAttributes(item, with: data)
    }

    
    /// Create a tags string from CatalogItemData, including manufacturer as a tag
    private func createTagsString(from data: CatalogItemData) -> String {
        var allTags: [String] = []
        
        // Add existing tags from JSON
        if let tags = data.tags, !tags.isEmpty {
            allTags.append(contentsOf: tags)
        }
        
        // Add manufacturer as a tag if it exists and isn't already in tags
        if let manufacturer = data.manufacturer, !manufacturer.isEmpty, manufacturer != "Unknown" {
            let lowercaseManufacturer = manufacturer.lowercased()
            let existingTagsLowercase = allTags.map { $0.lowercased() }
            if !existingTagsLowercase.contains(lowercaseManufacturer) {
                allTags.append(manufacturer)
            }
        }
        
        return allTags.joined(separator: ",")
    }
}

enum DataLoadingError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let message):
            return message
        case .decodingFailed(let message):
            return message
        }
    }
}

// Data models are now defined in CatalogDataModels.swift
