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
    private let jsonLoader = JSONDataLoader()
    private let catalogManager = CatalogItemManager()
    
    private init() {}
    
    // MARK: - Public API
    
    func loadCatalogItemsFromJSON(into context: NSManagedObjectContext) async throws {
        let data = try jsonLoader.findCatalogJSONData()
        let items = try jsonLoader.decodeCatalogItems(from: data)

        // Check existing count for logging purposes (duplicates check intentionally not enforced)
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        // Ensure entity is properly configured
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            throw DataLoadingError.decodingFailed("Could not find CatalogItem entity in context")
        }
        fetchRequest.entity = entity
        _ = try context.count(for: fetchRequest)

        try await processArray(items, context: context)
    }
    
    func loadCatalogItemsFromJSONSync(into context: NSManagedObjectContext) throws {
        let data = try jsonLoader.findCatalogJSONData()
        let items = try jsonLoader.decodeCatalogItems(from: data)

        for (index, catalogItemData) in items.enumerated() {
            _ = catalogManager.createCatalogItem(from: catalogItemData, in: context)
            if index < 3 { // Log first 3 items for debugging
                log.debug("Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code))")
            }
        }

        try CoreDataHelpers.safeSave(
            context: context,
            description: "\(items.count) items from JSON"
        )
    }
    
    /// Load JSON with comprehensive attribute merging - updates ALL changed attributes
    func loadCatalogItemsFromJSONWithMerge(into context: NSManagedObjectContext) async throws {
        
        let result = await ErrorHandler.shared.executeAsync(context: "JSON merge") {
            let data = try jsonLoader.findCatalogJSONData()
            let items = try jsonLoader.decodeCatalogItems(from: data)
            
            // Create a dictionary of existing items by code for fast lookup
            let existingItemsByCode = try catalogManager.fetchExistingItemsByCode(from: context)
            
            try await MainActor.run {
                var newItemsCount = 0
                var updatedItemsCount = 0
                var skippedItemsCount = 0
                
                for catalogItemData in items {
                    let fullCode = catalogManager.constructFullCodeForLookup(from: catalogItemData)
                    if let existingItem = existingItemsByCode[fullCode] {
                        // Item exists, check for any attribute changes
                        if catalogManager.shouldUpdateExistingItem(existingItem, with: catalogItemData) {
                            catalogManager.updateCatalogItem(existingItem, with: catalogItemData)
                            updatedItemsCount += 1
                        } else {
                            skippedItemsCount += 1
                        }
                    } else {
                        // New item, create it
                        _ = catalogManager.createCatalogItem(from: catalogItemData, in: context)
                        newItemsCount += 1
                    }
                }
                
                try CoreDataHelpers.safeSave(
                    context: context,
                    description: "comprehensive merge - \(newItemsCount) new, \(updatedItemsCount) updated, \(skippedItemsCount) unchanged"
                )
            }
        }
        
        switch result {
        case .success:
            break
        case .failure(let error):
            throw error
        }
    }
    
    /// Load JSON only if database is empty (safest approach)
    func loadCatalogItemsFromJSONIfEmpty(into context: NSManagedObjectContext) async throws {
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        // Ensure entity is properly configured
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            throw DataLoadingError.decodingFailed("Could not find CatalogItem entity in context")
        }
        fetchRequest.entity = entity
        let existingCount = try context.count(for: fetchRequest)
        
        if existingCount == 0 {
            try await loadCatalogItemsFromJSON(into: context)
        } else {
            log.warning("Database contains \(existingCount) items, skipping JSON load")
        }
    }
    
    // MARK: - Internal Methods for Testing
    
    /// Decodes catalog items from data - exposed for unit testing via @testable import
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        return try jsonLoader.decodeCatalogItems(from: data)
    }
    
    // MARK: - Private Processing Methods
    
    /// Unified method to process catalog items from any collection type
    private func processJSONData<T: Collection>(
        _ data: T,
        context: NSManagedObjectContext,
        dataType: String
    ) async throws where T.Element == CatalogItemData {
        try await MainActor.run {
            let itemsArray = Array(data)
            
            for (index, catalogItemData) in itemsArray.enumerated() {
                _ = catalogManager.createCatalogItem(from: catalogItemData, in: context)
                
                if index < 3 { // Log first 3 items for debugging
                    log.debug("Created item \(index + 1): \(catalogItemData.name) (\(catalogItemData.code))")
                }
            }
            
            try CoreDataHelpers.safeSave(
                context: context,
                description: "\(itemsArray.count) items from JSON \(dataType)"
            )
        }
    }
    
    /// Helper function to process array data
    private func processArray(_ jsonArray: [CatalogItemData], context: NSManagedObjectContext) async throws {
        try await processJSONData(jsonArray, context: context, dataType: "array")
    }
    
    /// Helper function to log Core Data errors with detailed information
    private func logCoreDataError(_ error: NSError) {
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



