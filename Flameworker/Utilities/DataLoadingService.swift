//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import Foundation
import CoreData
import OSLog

class DataLoadingService {
    static let shared = DataLoadingService()
    private let log = Logger.dataLoading
    
    private init() {}
    
    func loadCatalogItemsFromJSON(into context: NSManagedObjectContext) async throws {
        log.info("Starting JSON load process…")
        let data = try findJSONData()
        let items = try decodeCatalogItems(from: data)

        // Check existing count for logging purposes (duplicates check intentionally not enforced)
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCount = try context.count(for: fetchRequest)
        log.info("Existing CatalogItem count: \(existingCount)")

        try await processArray(items, context: context)
    }
    
    func loadCatalogItemsFromJSONSync(into context: NSManagedObjectContext) throws {
        log.info("Starting synchronous JSON load process…")
        let data = try findJSONData()
        let items = try decodeCatalogItems(from: data)

        for (index, catalogItemData) in items.enumerated() {
            _ = createCatalogItem(from: catalogItemData, in: context)
            if index < 3 { // Log first 3 items for debugging
                log.debug("Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code))")
            }
        }

        try CoreDataHelpers.safeSave(
            context: context,
            description: "\(items.count) items from JSON"
        )
        log.info("Successfully loaded \(items.count) items from JSON (sync)")
    }
    
    // MARK: - JSON Location and Decoding Helpers

    /// Finds and loads JSON data for the catalog from common bundle locations.
    private func findJSONData() throws -> Data {
        // Debug bundle contents
        if let bundlePath = Bundle.main.resourcePath {
            log.debug("Bundle path: \(bundlePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                let jsonFiles = contents.filter { $0.hasSuffix(".json") }
                log.debug("JSON files in bundle root: \(jsonFiles)")
                // Also check Data subdirectory
                let dataPath = (bundlePath as NSString).appendingPathComponent("Data")
                if FileManager.default.fileExists(atPath: dataPath) {
                    let dataContents = try FileManager.default.contentsOfDirectory(atPath: dataPath)
                    let dataJsonFiles = dataContents.filter { $0.hasSuffix(".json") }
                    log.debug("JSON files in Data folder: \(dataJsonFiles)")
                }
            } catch {
                log.error("Error reading bundle contents: \(String(describing: error))")
            }
        }

        // Candidate resource paths to try in order
        let candidateNames = [
            "colors.json",
            "Data/colors.json",
            "effetre.json",
            "Data/effetre.json"
        ]

        for name in candidateNames {
            let components = name.split(separator: "/")
            if components.count == 2 {
                // Use subdirectory-aware lookup
                let resource = String(components[1]).replacingOccurrences(of: ".json", with: "")
                let subdir = String(components[0])
                if let url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: subdir) {
                    log.info("Found \(name)")
                    if let data = try? Data(contentsOf: url) {
                        log.info("Loaded JSON data, size: \(data.count) bytes")
                        return data
                    } else {
                        log.warning("Failed to load data from \(name)")
                    }
                }
            } else if let url = Bundle.main.url(forResource: String(name).replacingOccurrences(of: ".json", with: ""), withExtension: "json") {
                log.info("Found \(name)")
                if let data = try? Data(contentsOf: url) {
                    log.info("Loaded JSON data, size: \(data.count) bytes")
                    return data
                } else {
                    log.warning("Failed to load data from \(name)")
                }
            }
        }

        throw DataLoadingError.fileNotFound("Could not find colors.json or effetre.json in bundle")
    }

    /// Decodes catalog items from data, supporting multiple JSON shapes and date formats.
    /// Internal for unit testing via @testable import
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        let decoder = JSONDecoder()

        // Try nested structure first
        if let wrapped = try? decoder.decode(WrappedColorsData.self, from: data) {
            log.info("Decoded nested JSON structure with \(wrapped.colors.count) items")
            return wrapped.colors
        }

        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]

        // Try dictionary/array with multiple date formats
        for format in possibleDateFormats {
            let df = DateFormatter()
            df.dateFormat = format
            decoder.dateDecodingStrategy = .formatted(df)

            if let dict = try? decoder.decode([String: CatalogItemData].self, from: data) {
                log.info("Decoded dictionary with \(dict.count) items using date format: \(format)")
                return Array(dict.values)
            }
            if let array = try? decoder.decode([CatalogItemData].self, from: data) {
                log.info("Decoded array with \(array.count) items using date format: \(format)")
                return array
            }
        }

        // Try without date formatting
        decoder.dateDecodingStrategy = .deferredToDate
        if let dict = try? decoder.decode([String: CatalogItemData].self, from: data) {
            log.info("Decoded dictionary without date formatting: \(dict.count) items")
            return Array(dict.values)
        }
        if let array = try? decoder.decode([CatalogItemData].self, from: data) {
            log.info("Decoded array without date formatting: \(array.count) items")
            return array
        }

        // Log a preview of the JSON to help debug
        if let jsonString = String(data: data, encoding: .utf8) {
            log.debug("First 500 characters of JSON: \(String(jsonString.prefix(500)))")
        }

        throw DataLoadingError.decodingFailed("Could not decode JSON in any supported format")
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
        setAttributeIfExists(item, key: "tags", value: tagsString.isEmpty ? nil : tagsString)
        
        // Handle optional attributes using helper method
        setAttributeIfExists(item, key: "image_path", value: data.image_path)
        setAttributeIfExists(item, key: "synonyms", value: CoreDataHelpers.joinStringArray(data.synonyms))
        setAttributeIfExists(item, key: "coe", value: data.coe)
    }
    
    // MARK: - Unified JSON Processing
    
    /// Unified method to process catalog items from any collection type
    private func processJSONData<T: Collection>(
        _ data: T,
        context: NSManagedObjectContext,
        dataType: String
    ) async throws where T.Element == CatalogItemData {
        try await MainActor.run {
            let itemsArray = Array(data)
            
            for (index, catalogItemData) in itemsArray.enumerated() {
                _ = createCatalogItem(from: catalogItemData, in: context)
                
                if index < 3 { // Log first 3 items for debugging
                    log.debug("Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code))")
                }
            }
            
            try CoreDataHelpers.safeSave(
                context: context,
                description: "\(itemsArray.count) items from JSON \(dataType)"
            )
            log.info("Successfully loaded \(itemsArray.count) items from JSON \(dataType)")
        }
    }
    
    // Helper function to process dictionary data
    private func processDictionary(_ jsonDictionary: [String: CatalogItemData], context: NSManagedObjectContext) async throws {
        try await processJSONData(jsonDictionary.values, context: context, dataType: "dictionary")
    }
    
    // Helper function to process array data
    private func processArray(_ jsonArray: [CatalogItemData], context: NSManagedObjectContext) async throws {
        try await processJSONData(jsonArray, context: context, dataType: "array")
    }
    /*
    func loadCatalogItemsFromJSONSync(into context: NSManagedObjectContext) throws {
        log.info("Starting synchronous JSON load process…")
        
        // First, let's debug what's in the bundle
        if let bundlePath = Bundle.main.resourcePath {
            log.debug("Bundle path: \(bundlePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                let jsonFiles = contents.filter { $0.hasSuffix(".json") }
                log.debug("JSON files in bundle root: \(jsonFiles)")
                
                // Also check Data subdirectory
                let dataPath = bundlePath + "/Data"
                if FileManager.default.fileExists(atPath: dataPath) {
                    let dataContents = try FileManager.default.contentsOfDirectory(atPath: dataPath)
                    let dataJsonFiles = dataContents.filter { $0.hasSuffix(".json") }
                    log.debug("JSON files in Data folder: \(dataJsonFiles)")
                }
            } catch {
                log.error("Error reading bundle contents: \(String(describing: error))")
            }
        }
        
        // Try multiple possible locations for the JSON file
        var url: URL?
        var data: Data?
        
        // First try: root of bundle
        if let rootUrl = Bundle.main.url(forResource: "colors", withExtension: "json") {
            log.info("Found colors.json in bundle root")
            url = rootUrl
        }
        // Second try: Data subdirectory
        else if let dataUrl = Bundle.main.url(forResource: "Data/colors", withExtension: "json") {
            log.info("Found colors.json in Data subdirectory")
            url = dataUrl
        }
        // Third try: effetre name in root
        else if let efferreUrl = Bundle.main.url(forResource: "effetre", withExtension: "json") {
            log.info("Found effetre.json in bundle root")
            url = efferreUrl
        }
        // Fourth try: effetre name in Data subdirectory
        else if let efferreDataUrl = Bundle.main.url(forResource: "Data/effetre", withExtension: "json") {
            log.info("Found effetre.json in Data subdirectory")
            url = efferreDataUrl
        }
        
        guard let jsonUrl = url else {
            log.error("Could not find colors.json or effetre.json in any location")
            throw DataLoadingError.fileNotFound("Could not find colors.json or effetre.json in bundle")
        }
        
        guard let jsonData = try? Data(contentsOf: jsonUrl) else {
            log.error("Could not load data from JSON file")
            throw DataLoadingError.fileNotFound("Could not load data from JSON file")
        }
        
        log.info("Successfully loaded JSON data, size: \(jsonData.count) bytes")
        
        // Check if items already exist to avoid duplicates
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCatalogItemsCount = try context.count(for: fetchRequest)
        /*
        guard existingCatalogItemsCount == 0 else {
            log.warning("CatalogItems already exist in Core Data (\(existingCatalogItemsCount) items), skipping JSON load")
            return
        }
         */
        
        // Fall back to standard JSON parsing
        let decoder = JSONDecoder()
        
        // Try the nested structure first (like the async method)
        do {
            let wrappedData = try decoder.decode(WrappedColorsData.self, from: jsonData)
            log.info("Successfully decoded \(wrappedData.colors.count) items from nested JSON structure")
            
            for catalogItemData in wrappedData.colors {
                _ = createCatalogItem(from: catalogItemData, in: context)
            }
            
            try CoreDataHelpers.safeSave(
                context: context,
                description: "\(wrappedData.colors.count) items from nested JSON structure"
            )
            return
        } catch {
            log.warning("Failed to decode as nested structure: \(error)")
        }
        
        // Fall back to dictionary format
        do {
            let jsonDictionary = try decoder.decode([String: CatalogItemData].self, from: jsonData)
            log.info("Successfully decoded \(jsonDictionary.count) items from JSON dictionary")
            
            for (_, catalogItemData) in jsonDictionary {
                _ = createCatalogItem(from: catalogItemData, in: context)
            }
            
            try CoreDataHelpers.safeSave(
                context: context,
                description: "\(jsonDictionary.count) items from JSON dictionary"
            )
        } catch {
            log.error("Failed to decode as dictionary: \(error)")
            throw DataLoadingError.decodingFailed("Failed to decode JSON: \(error.localizedDescription)")
        }
    }
    */
    
    // MARK: - Smart Merge Functionality
    
    /// Load JSON with comprehensive attribute merging - updates ALL changed attributes
    func loadCatalogItemsFromJSONWithMerge(into context: NSManagedObjectContext) async throws {
        log.info("Starting comprehensive JSON merge…")
        
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw DataLoadingError.fileNotFound("Could not find or load colors.json")
        }
        
        // Parse standard JSON data
        let wrappedData: WrappedColorsData
        let decoder = JSONDecoder()
        wrappedData = try decoder.decode(WrappedColorsData.self, from: data)
        log.info("Parsed \(wrappedData.colors.count) items from standard JSON")
        
        // Create a dictionary of existing items by code for fast lookup
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingItems = try context.fetch(fetchRequest)
        var existingItemsByCode = [String: CatalogItem]()
        
        for item in existingItems {
            if let code = item.code {
                existingItemsByCode[code] = item
            }
        }
        
        log.info("Found \(existingItems.count) existing items in Core Data")
        
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
                        log.info("Updated: \(catalogItemData.name) (\(catalogItemData.code))")
                    } else {
                        skippedItemsCount += 1
                    }
                } else {
                    // New item, create it
                    _ = createCatalogItem(from: catalogItemData, in: context)
                    newItemsCount += 1
                    log.info("Added: \(catalogItemData.name) (\(catalogItemData.code))")
                }
            }
            
            do {
                try CoreDataHelpers.safeSave(
                    context: context,
                    description: "comprehensive merge - \(newItemsCount) new, \(updatedItemsCount) updated, \(skippedItemsCount) unchanged"
                )
                log.info("Comprehensive merge complete!")
                log.info("   \(newItemsCount) new items added")
                log.info("   \(updatedItemsCount) items updated")
                log.info("   \(skippedItemsCount) items unchanged")
            } catch let error as NSError {
                log.error("Error saving comprehensive merge: \(error)")
                log.error("Error details:")
                log.error("   Domain: \(error.domain)")
                log.error("   Code: \(error.code)")
                log.error("   Description: \(error.localizedDescription)")
                
                // Check for validation errors
                if let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    log.error("Validation errors found:")
                    for (index, validationError) in validationErrors.enumerated() {
                        log.error("   Error \(index + 1):")
                        log.error("     Description: \(validationError.localizedDescription)")
                        log.error("     User Info: \(String(describing: validationError.userInfo))")
                        
                        // Check for specific validation keys
                        if let validationKey = validationError.userInfo[NSValidationKeyErrorKey] as? String {
                            log.error("     Invalid Key: \(validationKey)")
                        }
                        if let validationObject = validationError.userInfo[NSValidationObjectErrorKey] {
                            log.error("     Object: \(String(describing: validationObject))")
                        }
                    }
                } else {
                    log.error("Error user info: \(String(describing: error.userInfo))")
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
            log.info("Database is empty, loading JSON data…")
            try await loadCatalogItemsFromJSON(into: context)
        } else {
            log.warning("Database contains \(existingCount) items, skipping JSON load")
            log.info("Use 'Reset' button first if you want to reload from JSON")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Safe method to set Core Data attribute if it exists in the entity
    private func setAttributeIfExists(_ item: CatalogItem, key: String, value: String?) {
        let entityDescription = item.entity
        guard entityDescription.attributesByName[key] != nil else { return }
        item.setValue(value, forKey: key)
    }
    
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
            log.debug("Changes detected for \(new.code):")
            if idChanged { 
                let oldId = existing.value(forKey: "id") as? String ?? "nil"
                log.debug("   ID: '\(oldId)' -> '\(new.id ?? "nil")'") 
            }
            if nameChanged { log.debug("   Name: '\(existing.name ?? "nil")' -> '\(new.name)'") }
            if manufacturerChanged { log.debug("   Manufacturer: '\(existing.manufacturer ?? "nil")' -> '\(new.manufacturer ?? "nil")'") }
            if manufacturerDescriptionChanged { 
                let oldDesc = existing.value(forKey: "manufacturer_description") as? String ?? "nil"
                log.debug("   Manufacturer Description: '\(oldDesc)' -> '\(new.manufacturer_description ?? "nil")'") 
            }
            if tagsChanged {
                let oldTags = existing.value(forKey: "tags") as? String ?? ""
                let newTags = new.tags?.joined(separator: ",") ?? ""
                log.debug("   Tags: '\(oldTags)' -> '\(newTags)'") 
            }
            if startDateChanged {
                let oldDate = existing.start_date?.description ?? "nil"
                let newDate = new.start_date?.description ?? "nil"
                log.debug("   Start Date: '\(oldDate)' -> '\(newDate)'")
            }
            if endDateChanged {
                let oldDate = existing.end_date?.description ?? "nil"  
                let newDate = new.end_date?.description ?? "nil"
                log.debug("   End Date: '\(oldDate)' -> '\(newDate)'")
            }
            if imagePathChanged {
                let oldImagePath = existing.value(forKey: "image_path") as? String ?? "nil"
                log.debug("   Image Path: '\(oldImagePath)' -> '\(new.image_path ?? "nil")'")
            }
            if synonymsChanged {
                let oldSynonyms = existing.value(forKey: "synonyms") as? String ?? ""
                let newSynonyms = new.synonyms?.joined(separator: ",") ?? ""
                log.debug("   Synonyms: '\(oldSynonyms)' -> '\(newSynonyms)'")
            }
            if coeChanged {
                let oldCoe = existing.value(forKey: "coe") as? String ?? "nil"
                log.debug("   COE: '\(oldCoe)' -> '\(new.coe ?? "nil")'")
            }
        } else {
            log.info("No changes for \(new.code) - skipping update")
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



