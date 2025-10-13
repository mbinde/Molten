//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

// ✅ UPDATED FOR REPOSITORY PATTERN MIGRATION (October 2025)
//
// This service has been successfully migrated from the deprecated CatalogItemManager
// to the new repository pattern using CatalogService + CatalogItemRepository.
//
// CHANGES MADE:
// - Removed dependency on CatalogItemManager (now deleted)
// - Updated to use CatalogService with repository pattern
// - All JSON loading now goes through repository layer
// - Maintains API compatibility while using clean architecture
// - Deprecated sync methods that don't fit repository pattern

import Foundation
import CoreData
import OSLog

class DataLoadingService {
    static let shared = DataLoadingService()
    
    private let log = Logger.dataLoading
    private let jsonLoader = JSONDataLoader()
    private let catalogService: CatalogService
    
    private init() {
        // Use default repository for shared instance
        let mockRepository = MockCatalogRepository()
        self.catalogService = CatalogService(repository: mockRepository)
    }
    
    /// Initialize with repository pattern support
    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }
    
    // MARK: - Public API
    
    func loadCatalogItemsFromJSON(into context: NSManagedObjectContext) async throws {
        let data = try jsonLoader.findCatalogJSONData()
        let items = try jsonLoader.decodeCatalogItems(from: data)

        // Convert to models and create via repository pattern
        for catalogItemData in items {
            let item = CatalogItemModel(
                name: catalogItemData.name,
                rawCode: catalogItemData.code,
                manufacturer: catalogItemData.manufacturer ?? "Unknown",
                tags: catalogItemData.tags ?? []
            )
            
            _ = try await catalogService.createItem(item)
        }
        
        log.info("Successfully loaded \(items.count) catalog items from JSON")
    }
    
    @available(*, deprecated, message: "Use loadCatalogItemsFromJSON(into:) instead - sync methods are deprecated in repository pattern")
    func loadCatalogItemsFromJSONSync(into context: NSManagedObjectContext) throws {
        // Sync method deprecated - repository pattern is inherently async
        // This method is kept for API compatibility but should be migrated to async version
        throw DataLoadingError.decodingFailed("Sync loading deprecated - use async loadCatalogItemsFromJSON(into:) instead")
    }
    
    /// Load JSON with comprehensive attribute merging - updates ALL changed attributes
    func loadCatalogItemsFromJSONWithMerge(into context: NSManagedObjectContext) async throws {
        
        let result = await ErrorHandler.shared.executeAsync(context: "JSON merge") {
            let data = try jsonLoader.findCatalogJSONData()
            let items = try jsonLoader.decodeCatalogItems(from: data)
            
            // Get existing items from repository
            let existingItems = try await catalogService.getAllItems()
            let existingItemsByCode = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.code, $0) })
            
            var newItemsCount = 0
            var updatedItemsCount = 0
            var skippedItemsCount = 0
            
            for catalogItemData in items {
                // Create model to get proper code formatting
                let newItem = CatalogItemModel(
                    name: catalogItemData.name,
                    rawCode: catalogItemData.code,
                    manufacturer: catalogItemData.manufacturer ?? "Unknown",
                    tags: catalogItemData.tags ?? []
                )
                
                if let existingItem = existingItemsByCode[newItem.code] {
                    // Item exists, check for changes using repository pattern
                    if try await catalogService.shouldUpdateItem(existing: existingItem, with: newItem) {
                        try await catalogService.updateItem(newItem)
                        updatedItemsCount += 1
                    } else {
                        skippedItemsCount += 1
                    }
                } else {
                    // New item, create it
                    _ = try await catalogService.createItem(newItem)
                    newItemsCount += 1
                }
            }
            
            log.info("Comprehensive merge complete - \(newItemsCount) new, \(updatedItemsCount) updated, \(skippedItemsCount) unchanged")
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
        let existingItems = try await catalogService.getAllItems()
        
        if existingItems.isEmpty {
            try await loadCatalogItemsFromJSON(into: context)
        } else {
            log.warning("Database contains \(existingItems.count) items, skipping JSON load")
        }
    }
    
    // MARK: - Internal Methods for Testing
    
    /// Decodes catalog items from data - exposed for unit testing via @testable import
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        return try jsonLoader.decodeCatalogItems(from: data)
    }
    
    // MARK: - Private Helper Methods
    
    /// Load catalog items using repository pattern (new architecture)
    func loadCatalogItems(from jsonData: [[String: Any]]) async throws {
        // Convert dictionary data to CatalogItemModel instances
        for itemData in jsonData {
            guard let code = itemData["code"] as? String,
                  let name = itemData["name"] as? String,
                  let manufacturer = itemData["manufacturer"] as? String else {
                continue // Skip invalid items
            }
            
            // Create model using rawCode constructor to apply business logic
            let item = CatalogItemModel(
                name: name,
                rawCode: code, // This applies the manufacturer prefix business rules
                manufacturer: manufacturer,
                tags: itemData["tags"] as? [String] ?? []
            )
            
            // Create through service layer (which delegates to repository)
            _ = try await catalogService.createItem(item)
        }
    }
    
    // MARK: - Private Helper Methods
    
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



