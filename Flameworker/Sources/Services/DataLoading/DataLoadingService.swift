//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//  Enhanced by Assistant on 10/14/25.
//

// ✅ UPDATED FOR GLASS ITEM SYSTEM (October 2025)
//
// This service now supports both legacy and new GlassItem systems:
// - Legacy system: Uses CatalogService with CatalogItemRepository (backward compatibility)
// - New system: Uses GlassItemDataLoadingService for full GlassItem support
// - Provides migration capabilities between systems
// - Maintains API compatibility while offering enhanced functionality

import Foundation
import OSLog

#if canImport(CoreData)
import CoreData
#endif

class DataLoadingService {
    static let shared = DataLoadingService()
    
    private let log = Logger.dataLoading
    private let jsonLoader = JSONDataLoader()
    private let catalogService: CatalogService
    private let glassItemLoadingService: GlassItemDataLoadingService?
    
    private init() {
        // Use default repository for shared instance (legacy compatibility)
        let mockRepository = MockCatalogRepository()
        self.catalogService = CatalogService(repository: mockRepository)
        self.glassItemLoadingService = nil
    }
    
    /// Initialize with repository pattern support (legacy system)
    init(catalogService: CatalogService) {
        self.catalogService = catalogService
        self.glassItemLoadingService = nil
    }
    
    /// Initialize with new GlassItem system support
    init(catalogService: CatalogService, glassItemLoadingService: GlassItemDataLoadingService) {
        self.catalogService = catalogService
        self.glassItemLoadingService = glassItemLoadingService
    }
    
    // MARK: - System Detection
    
    /// Determine which loading system to use based on catalog service configuration
    private var preferNewSystem: Bool {
        return glassItemLoadingService != nil
    }
    
    // MARK: - Enhanced Public API
    
    /// Load catalog items from JSON using the best available system
    /// - Parameter options: Loading options (only used for new system)
    /// - Returns: Results indicating which system was used and outcome
    func loadCatalogItemsFromJSON(
        options: GlassItemDataLoadingService.LoadingOptions = .default
    ) async throws -> DataLoadingResult {
        
        if preferNewSystem, let glassItemService = glassItemLoadingService {
            log.info("Loading catalog items using new GlassItem system")
            
            let result = try await glassItemService.loadGlassItemsFromJSON(options: options)
            return DataLoadingResult.fromGlassItemResult(result)
            
        } else {
            log.info("Loading catalog items using legacy system")
            
            try await loadCatalogItemsFromJSONLegacy()
            return DataLoadingResult.legacySuccess()
        }
    }
    
    /// Load catalog items only if the system is empty
    /// - Parameter options: Loading options (only used for new system)
    /// - Returns: Results or nil if system already has data
    func loadCatalogItemsFromJSONIfEmpty(
        options: GlassItemDataLoadingService.LoadingOptions = .default
    ) async throws -> DataLoadingResult? {
        
        if preferNewSystem, let glassItemService = glassItemLoadingService {
            log.info("Checking if GlassItem system is empty")
            
            if let result = try await glassItemService.loadGlassItemsFromJSONIfEmpty(options: options) {
                return DataLoadingResult.fromGlassItemResult(result)
            } else {
                return nil
            }
            
        } else {
            log.info("Checking if legacy system is empty")
            
            let existingItems = try await catalogService.getAllItems()
            if existingItems.isEmpty {
                try await loadCatalogItemsFromJSONLegacy()
                return DataLoadingResult.legacySuccess()
            } else {
                log.warning("Legacy system contains \(existingItems.count) items, skipping JSON load")
                return nil
            }
        }
    }
    
    /// Perform migration from legacy to new GlassItem system
    /// This method requires both systems to be available
    /// - Returns: Migration results
    func migrateFromLegacyToGlassItem() async throws -> MigrationResult {
        guard let glassItemService = glassItemLoadingService else {
            throw DataLoadingError.newSystemNotAvailable
        }
        
        log.info("Starting migration from legacy to GlassItem system")
        
        // Get migration status first
        let migrationStatus = try await catalogService.getMigrationStatus()
        
        guard migrationStatus.canMigrate else {
            throw DataLoadingError.migrationNotPossible("Migration not possible: \(migrationStatus.description)")
        }
        
        // Perform the migration
        let loadingResult = try await glassItemService.migrateFromLegacySystem()
        
        // Validate migration success
        let postMigrationStatus = try await catalogService.getMigrationStatus()
        
        return MigrationResult(
            preMigrationStatus: migrationStatus,
            loadingResult: loadingResult,
            postMigrationStatus: postMigrationStatus,
            migrationSuccessful: loadingResult.itemsCreated > 0
        )
    }
    
    /// Validate JSON data without loading it
    /// - Returns: Validation results
    func validateJSONData() async throws -> JSONValidationResult {
        if let glassItemService = glassItemLoadingService {
            return try await glassItemService.validateJSONData()
        } else {
            // Basic validation for legacy system
            let data = try jsonLoader.findCatalogJSONData()
            let items = try jsonLoader.decodeCatalogItems(from: data)
            
            var result = JSONValidationResult()
            result.totalItemsFound = items.count
            
            // Basic validation - just check that items can be decoded
            for (index, item) in items.enumerated() {
                var validation = ItemValidationResult()
                validation.itemIndex = index
                validation.itemCode = item.code
                validation.itemName = item.name
                
                if item.name.isEmpty {
                    validation.errors.append("Name is empty")
                }
                if item.code.isEmpty {
                    validation.errors.append("Code is empty")
                }
                
                result.merge(validation)
            }
            
            return result
        }
    }
    
    // MARK: - Legacy API (Maintained for Backward Compatibility)
    
    /// Load catalog items from JSON (legacy implementation)
    private func loadCatalogItemsFromJSONLegacy() async throws {
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
        
        log.info("Successfully loaded \(items.count) catalog items from JSON using legacy system")
    }
    
    /// Load JSON with comprehensive attribute merging (legacy implementation)
    func loadCatalogItemsFromJSONWithMerge() async throws {
        if preferNewSystem {
            // For new system, use migration-friendly options
            _ = try await loadCatalogItemsFromJSON(options: .migration)
            return
        }
        
        // Legacy implementation
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

    @available(*, deprecated, message: "Use loadCatalogItemsFromJSON() instead - sync methods are deprecated in repository pattern")
    func loadCatalogItemsFromJSONSync() throws {
        // Sync method deprecated - repository pattern is inherently async
        // This method is kept for API compatibility but should be migrated to async version
        throw DataLoadingError.decodingFailed("Sync loading deprecated - use async loadCatalogItemsFromJSON() instead")
    }
    
    // MARK: - Internal Methods for Testing
    
    /// Decodes catalog items from data - exposed for unit testing via @testable import
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        return try jsonLoader.decodeCatalogItems(from: data)
    }
    
    // MARK: - Private Helper Methods
    
    /// Load catalog items using repository pattern (legacy architecture)
    private func loadCatalogItems(from jsonData: [[String: Any]]) async throws {
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
    
    /// Helper function to log errors with detailed information
    private func logError(_ error: Error) {
        log.error("Error details:")
        log.error("   Description: \(error.localizedDescription)")
        
        // If it's an NSError, log additional details
        if let nsError = error as NSError? {
            log.error("   Domain: \(nsError.domain)")
            log.error("   Code: \(nsError.code)")
            
            // Check for validation errors
            if let validationErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
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
                log.error("Error user info: \(String(describing: nsError.userInfo))")
            }
        }
    }
}

// MARK: - Enhanced Result Models

/// Unified result model for data loading operations
struct DataLoadingResult {
    let systemUsed: LoadingSystem
    let itemsProcessed: Int
    let itemsCreated: Int
    let itemsFailed: Int
    let itemsSkipped: Int
    let successRate: Double
    let details: String
    
    /// Create result from GlassItem loading result
    static func fromGlassItemResult(_ result: GlassItemLoadingResult) -> DataLoadingResult {
        return DataLoadingResult(
            systemUsed: .glassItem,
            itemsProcessed: result.totalProcessed,
            itemsCreated: result.itemsCreated,
            itemsFailed: result.itemsFailed,
            itemsSkipped: result.itemsSkipped,
            successRate: result.successRate,
            details: "Loaded using new GlassItem system with \(result.successfulItems.count) complete items"
        )
    }
    
    /// Create result for legacy system success
    static func legacySuccess() -> DataLoadingResult {
        return DataLoadingResult(
            systemUsed: .legacy,
            itemsProcessed: -1, // Unknown for legacy
            itemsCreated: -1,   // Unknown for legacy
            itemsFailed: 0,
            itemsSkipped: 0,
            successRate: 100.0,
            details: "Loaded using legacy system"
        )
    }
}

/// Which loading system was used
enum LoadingSystem {
    case legacy
    case glassItem
}

/// Result of a migration operation
struct MigrationResult {
    let preMigrationStatus: MigrationStatusModel
    let loadingResult: GlassItemLoadingResult
    let postMigrationStatus: MigrationStatusModel
    let migrationSuccessful: Bool
    
    /// Summary of the migration
    var summary: String {
        return """
        Migration Summary:
        - Pre-migration: \(preMigrationStatus.description)
        - Items migrated: \(loadingResult.itemsCreated)
        - Items failed: \(loadingResult.itemsFailed)
        - Success rate: \(String(format: "%.1f", loadingResult.successRate))%
        - Post-migration: \(postMigrationStatus.description)
        - Overall success: \(migrationSuccessful ? "YES" : "NO")
        """
    }
}

// MARK: - Enhanced Errors

enum DataLoadingError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    case newSystemNotAvailable
    case migrationNotPossible(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let message):
            return message
        case .decodingFailed(let message):
            return message
        case .newSystemNotAvailable:
            return "New GlassItem system not available for this operation"
        case .migrationNotPossible(let reason):
            return "Migration not possible: \(reason)"
        }
    }
}



