//
//  GlassItemDataLoadingService.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import OSLog

// Import required models and types from other modules
// Note: In a real project, these would be proper module imports

/// Service for loading data from JSON files into the new GlassItem system
/// Handles transformation from legacy JSON format to the new normalized entity structure
/// Supports initial loading, migration from legacy system, and bulk import operations
class GlassItemDataLoadingService {
    
    // MARK: - Dependencies
    
    private let catalogService: CatalogService
    private let jsonLoader: JSONDataLoading
    private let log = Logger(subsystem: "Flameworker", category: "GlassItemDataLoading")
    
    // MARK: - Configuration
    
    /// Options for controlling the data loading behavior
    struct LoadingOptions {
        let skipExistingItems: Bool
        let createInitialInventory: Bool
        let defaultInventoryType: String
        let defaultInventoryQuantity: Double
        let enableTagExtraction: Bool
        let enableSynonymTags: Bool
        let validateNaturalKeys: Bool
        let batchSize: Int
        
        static let `default` = LoadingOptions(
            skipExistingItems: true,
            createInitialInventory: false,
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 0.0,
            enableTagExtraction: true,
            enableSynonymTags: true,
            validateNaturalKeys: true,
            batchSize: 50
        )
        
        static let migration = LoadingOptions(
            skipExistingItems: false, // Overwrite during migration
            createInitialInventory: true,
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 1.0, // Assume 1 unit for migration
            enableTagExtraction: true,
            enableSynonymTags: true,
            validateNaturalKeys: true,
            batchSize: 25 // Smaller batches for migration stability
        )
        
        static let testing = LoadingOptions(
            skipExistingItems: false,
            createInitialInventory: true,
            defaultInventoryType: "test",
            defaultInventoryQuantity: 10.0,
            enableTagExtraction: true,
            enableSynonymTags: false, // Simpler for testing
            validateNaturalKeys: true,
            batchSize: 10
        )
    }
    
    // MARK: - Initialization
    
    init(catalogService: CatalogService, jsonLoader: JSONDataLoading = JSONDataLoader()) {
        self.catalogService = catalogService
        self.jsonLoader = jsonLoader
    }
    
    // MARK: - Public API
    
    /// Load glass items from colors.json into the new GlassItem system
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadGlassItemsFromJSON(options: LoadingOptions = .default) async throws -> GlassItemLoadingResult {
        // Validate system readiness
        try await catalogService.validateSystemReadiness()
        
        log.info("Starting GlassItem data loading from JSON with options: \(String(describing: options))")
        
        // Load and decode JSON data
        let data = try jsonLoader.findCatalogJSONData()
        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)
        
        log.info("Loaded \(catalogItems.count) items from JSON, beginning transformation")
        
        // Transform to GlassItem creation requests
        let creationRequests = await transformCatalogItemsToGlassItems(
            catalogItems,
            options: options
        )
        
        log.info("Transformed to \(creationRequests.count) GlassItem creation requests")
        
        // Process in batches
        var results = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )
        let batches = stride(from: 0, to: creationRequests.count, by: options.batchSize).map {
            Array(creationRequests[$0..<min($0 + options.batchSize, creationRequests.count)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            log.info("Processing batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items)")
            
            do {
                let batchResults = try await processBatch(batch, options: options)
                results.merge(batchResults)
                
                // Brief pause between batches to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                
            } catch {
                log.error("Failed to process batch \(batchIndex + 1): \(error.localizedDescription)")
                results.batchErrors.append(BatchError(
                    batchIndex: batchIndex,
                    itemsInBatch: batch.count,
                    error: error
                ))
            }
        }
        
        // Log final results
        logLoadingResults(results)
        
        return results
    }
    
    /// Load glass items and update existing items with any changes from JSON
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation, including updates to existing items
    func loadGlassItemsAndUpdateExisting(options: LoadingOptions = .default) async throws -> GlassItemLoadingResult {
        // Always proceed with loading - this method is designed to update existing data
        log.info("Loading GlassItem data from JSON and updating existing items")
        
        // Create options that allow updating existing items
        let updateOptions = LoadingOptions(
            skipExistingItems: false, // Always process existing items to check for updates
            createInitialInventory: options.createInitialInventory,
            defaultInventoryType: options.defaultInventoryType,
            defaultInventoryQuantity: options.defaultInventoryQuantity,
            enableTagExtraction: options.enableTagExtraction,
            enableSynonymTags: options.enableSynonymTags,
            validateNaturalKeys: options.validateNaturalKeys,
            batchSize: options.batchSize
        )
        
        return try await loadGlassItemsFromJSON(options: updateOptions)
    }
    
    /// Load glass items only if the new system is empty
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation, or nil if system already has data
    func loadGlassItemsFromJSONIfEmpty(options: LoadingOptions = .default) async throws -> GlassItemLoadingResult? {
        // Check if new system has any data
        let existingItems = try await catalogService.getAllGlassItems()
        
        if existingItems.isEmpty {
            log.info("New GlassItem system is empty, proceeding with JSON load")
            return try await loadGlassItemsFromJSON(options: options)
        } else {
            log.warning("New GlassItem system contains \(existingItems.count) items, skipping JSON load")
            return nil
        }
    }
    
    /// Migrate data from legacy system to new GlassItem system
    /// This method loads from JSON but with migration-friendly settings
    /// - Returns: Results of the migration operation
    func migrateFromLegacySystem() async throws -> GlassItemLoadingResult {
        log.info("Beginning migration from legacy system to GlassItem system")
        
        // Use migration-specific options
        let migrationOptions = LoadingOptions.migration
        
        return try await loadGlassItemsFromJSON(options: migrationOptions)
    }
    
    /// Validate JSON data without actually loading it
    /// - Returns: Validation results with potential issues identified
    func validateJSONData() async throws -> JSONValidationResult {
        let data = try jsonLoader.findCatalogJSONData()
        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)
        
        var result = JSONValidationResult(
            totalItemsFound: 0,
            itemsWithErrors: 0,
            itemsWithWarnings: 0,
            validationDetails: []
        )
        result.totalItemsFound = catalogItems.count
        
        // Validate each item
        for (index, item) in catalogItems.enumerated() {
            let validation = await validateCatalogItem(item, index: index)
            result.merge(validation)
        }
        
        return result
    }
    
    // MARK: - Private Implementation
    
    /// Transform CatalogItemData to GlassItemCreationRequest
    private func transformCatalogItemsToGlassItems(
        _ catalogItems: [CatalogItemData],
        options: LoadingOptions
    ) async -> [GlassItemCreationRequest] {
        var requests: [GlassItemCreationRequest] = []
        
        for catalogItem in catalogItems {
            // Skip if item already exists and we're configured to skip
            if options.skipExistingItems {
                let naturalKey = generateNaturalKey(from: catalogItem)
                if let exists = try? await catalogService.isNaturalKeyAvailable(naturalKey),
                   !exists {
                    log.debug("Skipping existing item: \(naturalKey)")
                    continue
                }
            }
            
            let request = await transformSingleItem(catalogItem, options: options)
            requests.append(request)
        }
        
        return requests
    }
    
    /// Transform a single CatalogItemData to GlassItemCreationRequest
    private func transformSingleItem(
        _ catalogItem: CatalogItemData,
        options: LoadingOptions
    ) async -> GlassItemCreationRequest {
        
        // Extract basic information
        let manufacturer = extractManufacturer(from: catalogItem)
        let sku = extractSKU(from: catalogItem)
        let coe = extractCOE(from: catalogItem)
        
        // Generate or use custom natural key
        let naturalKey = generateNaturalKey(from: catalogItem)
        
        // Extract tags
        var tags: [String] = []
        if options.enableTagExtraction {
            tags.append(contentsOf: extractTags(from: catalogItem))
        }
        if options.enableSynonymTags {
            tags.append(contentsOf: extractSynonymTags(from: catalogItem))
        }
        
        // Create initial inventory if requested
        var initialInventory: [InventoryModel] = []
        if options.createInitialInventory && options.defaultInventoryQuantity > 0 {
            let inventory = InventoryModel(
                item_natural_key: naturalKey,
                type: options.defaultInventoryType,
                quantity: options.defaultInventoryQuantity
            )
            initialInventory.append(inventory)
        }
        
        return GlassItemCreationRequest(
            name: catalogItem.name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: catalogItem.manufacturer_description,
            coe: coe,
            url: catalogItem.manufacturer_url,
            mfr_status: extractManufacturerStatus(from: catalogItem),
            customNaturalKey: naturalKey,
            initialInventory: initialInventory,
            tags: Array(Set(tags)) // Remove duplicates
        )
    }
    
    /// Process a batch of creation requests
    private func processBatch(
        _ batch: [GlassItemCreationRequest],
        options: LoadingOptions
    ) async throws -> GlassItemLoadingResult {
        var result = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )
        
        // Try to create all items in the batch
        do {
            let createdItems = try await catalogService.createGlassItems(batch)
            result.successfulItems.append(contentsOf: createdItems)
            result.itemsCreated += createdItems.count
        } catch {
            // If batch creation fails, try individual items
            log.warning("Batch creation failed, trying individual items: \(error.localizedDescription)")
            
            for request in batch {
                do {
                    let glassItem = GlassItemModel(
                        natural_key: request.customNaturalKey ?? "unknown",
                        name: request.name,
                        sku: request.sku,
                        manufacturer: request.manufacturer,
                        mfr_notes: request.mfr_notes,
                        coe: request.coe,
                        url: request.url,
                        mfr_status: request.mfr_status
                    )
                    
                    let createdItem = try await catalogService.createGlassItem(
                        glassItem,
                        initialInventory: request.initialInventory,
                        tags: request.tags
                    )
                    
                    result.successfulItems.append(createdItem)
                    result.itemsCreated += 1
                    
                } catch {
                    let failedItem = FailedGlassItem(
                        originalData: catalogItemFromRequest(request),
                        error: error,
                        failureReason: error.localizedDescription
                    )
                    result.failedItems.append(failedItem)
                    result.itemsFailed += 1
                }
            }
        }
        
        return result
    }
    
    // MARK: - Data Extraction Helpers
    
    /// Extract manufacturer from CatalogItemData
    private func extractManufacturer(from catalogItem: CatalogItemData) -> String {
        // Use manufacturer field if available, otherwise try to extract from code
        if let manufacturer = catalogItem.manufacturer, !manufacturer.isEmpty {
            return manufacturer.lowercased()
        }
        
        // Try to extract manufacturer from code (assuming format like "CIM-123")
        let codeParts = catalogItem.code.components(separatedBy: "-")
        if codeParts.count >= 2 {
            return codeParts[0].lowercased()
        }
        
        return "unknown"
    }
    
    /// Extract SKU from CatalogItemData
    private func extractSKU(from catalogItem: CatalogItemData) -> String {
        // Try to extract SKU from code (assuming format like "CIM-123")
        let codeParts = catalogItem.code.components(separatedBy: "-")
        if codeParts.count >= 2 {
            return codeParts[1]
        }
        
        // Fall back to the full code
        return catalogItem.code
    }
    
    /// Extract COE from CatalogItemData
    private func extractCOE(from catalogItem: CatalogItemData) -> Int32 {
        guard let coeString = catalogItem.coe else { return 96 } // Default to 96
        
        // Try to parse as integer
        if let coeInt = Int32(coeString) {
            return coeInt
        }
        
        // Try to parse as double and convert
        if let coeDouble = Double(coeString) {
            return Int32(coeDouble)
        }
        
        return 96 // Default fallback
    }
    
    /// Extract tags from CatalogItemData
    private func extractTags(from catalogItem: CatalogItemData) -> [String] {
        var tags: [String] = []
        
        // Add explicit tags
        if let itemTags = catalogItem.tags {
            tags.append(contentsOf: itemTags)
        }
        
        // Add manufacturer as a tag
        if let manufacturer = catalogItem.manufacturer, !manufacturer.isEmpty {
            tags.append(manufacturer.lowercased())
        }
        
        // Add COE as a tag
        if let coe = catalogItem.coe {
            tags.append("coe-\(coe)")
        }
        
        // Add stock type as a tag if available
        if let stockType = catalogItem.stock_type, !stockType.isEmpty {
            tags.append(stockType.lowercased())
        }
        
        return tags.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
               .filter { !$0.isEmpty }
    }
    
    /// Extract synonym-based tags from CatalogItemData
    private func extractSynonymTags(from catalogItem: CatalogItemData) -> [String] {
        guard let synonyms = catalogItem.synonyms else { return [] }
        
        return synonyms.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
                      .filter { !$0.isEmpty }
                      .map { "synonym-\($0)" }
    }
    
    /// Extract manufacturer status from CatalogItemData
    private func extractManufacturerStatus(from catalogItem: CatalogItemData) -> String {
        // Default to "available" if no specific status information
        return "available"
    }
    
    /// Generate natural key from CatalogItemData
    private func generateNaturalKey(from catalogItem: CatalogItemData) -> String {
        let manufacturer = extractManufacturer(from: catalogItem)
        let sku = extractSKU(from: catalogItem)
        return GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
    }
    
    /// Validate a single catalog item
    private func validateCatalogItem(_ catalogItem: CatalogItemData, index: Int) async -> ItemValidationResult {
        var result = ItemValidationResult(
            itemIndex: 0,
            itemCode: "",
            itemName: "",
            errors: [],
            warnings: []
        )
        result.itemIndex = index
        result.itemCode = catalogItem.code
        result.itemName = catalogItem.name
        
        // Check required fields
        if catalogItem.name.isEmpty {
            result.errors.append("Name is empty")
        }
        
        if catalogItem.code.isEmpty {
            result.errors.append("Code is empty")
        }
        
        // Validate COE
        let coe = extractCOE(from: catalogItem)
        if coe < 80 || coe > 120 {
            result.warnings.append("COE value \(coe) is outside typical range (80-120)")
        }
        
        // Validate manufacturer
        let manufacturer = extractManufacturer(from: catalogItem)
        if manufacturer == "unknown" {
            result.warnings.append("Could not determine manufacturer")
        }
        
        // Validate natural key
        let naturalKey = generateNaturalKey(from: catalogItem)
        if let isAvailable = try? await catalogService.isNaturalKeyAvailable(naturalKey),
           !isAvailable {
            result.warnings.append("Natural key \(naturalKey) already exists")
        }
        
        return result
    }
    
    /// Convert GlassItemCreationRequest back to CatalogItemData for error reporting
    private func catalogItemFromRequest(_ request: GlassItemCreationRequest) -> CatalogItemData {
        return CatalogItemData(
            id: nil,
            code: "\(request.manufacturer)-\(request.sku)",
            manufacturer: request.manufacturer,
            name: request.name,
            manufacturer_description: request.mfr_notes,
            synonyms: nil,
            tags: request.tags,
            image_path: nil,
            coe: String(request.coe),
            stock_type: request.initialInventory.first?.type,
            image_url: nil,
            manufacturer_url: request.url
        )
    }
    
    /// Log the final loading results
    private func logLoadingResults(_ result: GlassItemLoadingResult) {
        log.info("=== GlassItem Loading Results ===")
        log.info("Items Created: \(result.itemsCreated)")
        log.info("Items Failed: \(result.itemsFailed)")
        log.info("Items Skipped: \(result.itemsSkipped)")
        log.info("Batch Errors: \(result.batchErrors.count)")
        
        if !result.failedItems.isEmpty {
            log.warning("Failed items:")
            for (index, failed) in result.failedItems.prefix(5).enumerated() {
                log.warning("  \(index + 1). \(failed.originalData.name) (\(failed.originalData.code)): \(failed.failureReason)")
            }
            if result.failedItems.count > 5 {
                log.warning("  ... and \(result.failedItems.count - 5) more")
            }
        }
        
        if !result.batchErrors.isEmpty {
            log.error("Batch errors:")
            for batchError in result.batchErrors {
                log.error("  Batch \(batchError.batchIndex): \(batchError.error.localizedDescription)")
            }
        }
        
        log.info("=== End Loading Results ===")
    }
}

// MARK: - Result Models

/// Results of a GlassItem loading operation
struct GlassItemLoadingResult {
    var itemsCreated: Int = 0
    var itemsFailed: Int = 0
    var itemsSkipped: Int = 0
    var successfulItems: [CompleteInventoryItemModel] = []
    var failedItems: [FailedGlassItem] = []
    var batchErrors: [BatchError] = []
    
    /// Merge another result into this one
    mutating func merge(_ other: GlassItemLoadingResult) {
        itemsCreated += other.itemsCreated
        itemsFailed += other.itemsFailed
        itemsSkipped += other.itemsSkipped
        successfulItems.append(contentsOf: other.successfulItems)
        failedItems.append(contentsOf: other.failedItems)
        batchErrors.append(contentsOf: other.batchErrors)
    }
    
    /// Total items processed
    var totalProcessed: Int {
        itemsCreated + itemsFailed + itemsSkipped
    }
    
    /// Success rate as a percentage
    var successRate: Double {
        let total = totalProcessed
        return total > 0 ? (Double(itemsCreated) / Double(total)) * 100.0 : 0.0
    }
}

/// Information about a failed glass item creation
struct FailedGlassItem {
    let originalData: CatalogItemData
    let error: Error
    let failureReason: String
}

/// Information about a batch processing error
struct BatchError {
    let batchIndex: Int
    let itemsInBatch: Int
    let error: Error
}

/// Results of JSON validation
struct JSONValidationResult {
    var totalItemsFound: Int = 0
    var itemsWithErrors: Int = 0
    var itemsWithWarnings: Int = 0
    var validationDetails: [ItemValidationResult] = []
    
    /// Merge another validation result into this one
    mutating func merge(_ other: ItemValidationResult) {
        validationDetails.append(other)
        if !other.errors.isEmpty {
            itemsWithErrors += 1
        }
        if !other.warnings.isEmpty {
            itemsWithWarnings += 1
        }
    }
}

/// Validation result for a single item
struct ItemValidationResult {
    var itemIndex: Int = 0
    var itemCode: String = ""
    var itemName: String = ""
    var errors: [String] = []
    var warnings: [String] = []
    
    /// Whether this item is valid (no errors)
    var isValid: Bool {
        errors.isEmpty
    }
}


