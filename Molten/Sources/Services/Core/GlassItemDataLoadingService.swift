//
//  GlassItemDataLoadingService.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//  Refactored 2025-11-12: Split into focused components
//

import Foundation
import OSLog

/// Protocol for glass item data loading operations (for dependency injection)
protocol GlassItemDataLoadingServiceProtocol {
    func loadGlassItemsFromData(_ data: Data, options: LoadingOptions) async throws -> GlassItemLoadingResult
}

/// Service for loading data from JSON files into the new GlassItem system
/// Orchestrates catalog data loading using specialized components
/// Handles OTA updates, batch processing, and incremental syncing
@preconcurrency
class GlassItemDataLoadingService: GlassItemDataLoadingServiceProtocol {

    // MARK: - Dependencies

    nonisolated private let catalogService: CatalogService
    nonisolated(unsafe) private let jsonLoader: JSONDataLoading
    nonisolated private let catalogStorageService: CatalogStorageService?

    // Component dependencies
    nonisolated private let checksumManager: CatalogChecksumManager
    nonisolated private let versionManager: CatalogVersionManager
    nonisolated private let validator: CatalogDataValidator
    nonisolated private let processor: CatalogDataProcessor

    private let log = Logger(subsystem: "Flameworker", category: "GlassItemDataLoading")
    
    // MARK: - Checksum & Version Management (delegated to components)

    /// Check if JSON file has changed since last load
    /// - Returns: true if file has changed or is first run, false if unchanged
    func hasJSONFileChanged() throws -> Bool {
        try checksumManager.hasFileChanged()
    }

    /// Save current JSON file checksum after successful load
    func saveJSONChecksum() throws {
        try checksumManager.saveChecksum()
    }

    /// Check if JSON has newer version requiring data wipe
    /// - Returns: true if wipe needed, false otherwise
    func needsCatalogDataWipe() throws -> Bool {
        try versionManager.needsCatalogDataWipe()
    }

    /// Save current catalog data version after successful load
    func saveCatalogDataVersion() throws {
        try versionManager.saveCatalogDataVersion()
    }

    /// Delete all catalog-related data (GlassItems and tags)
    func wipeCatalogData() async throws {
        try await versionManager.wipeCatalogData()
    }

    // MARK: - Initialization

    nonisolated init(
        catalogService: CatalogService,
        jsonLoader: JSONDataLoading = JSONDataLoader(),
        catalogStorageService: CatalogStorageService? = nil
    ) {
        self.catalogService = catalogService
        self.jsonLoader = jsonLoader
        self.catalogStorageService = catalogStorageService

        // Initialize component dependencies
        self.checksumManager = CatalogChecksumManager()
        self.versionManager = CatalogVersionManager(jsonLoader: jsonLoader, catalogService: catalogService)
        self.validator = CatalogDataValidator(jsonLoader: jsonLoader, catalogService: catalogService)
        self.processor = CatalogDataProcessor(catalogService: catalogService)
    }
    
    // MARK: - Public API
    
    /// Load glass items from glassitems.json into the new GlassItem system
    /// Checks for OTA (downloaded) catalog first, falls back to bundled JSON if not available
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadGlassItemsFromJSON(options: LoadingOptions = .default) async throws -> GlassItemLoadingResult {
        // Skip system readiness validation for initial loading scenarios
        // The validateSystemReadiness check was preventing initial data loading into empty systems
        // TODO: Add a more appropriate validation that allows initial loading but prevents other issues

        log.info("Starting GlassItem data loading from JSON with options: \(String(describing: options))")

        // Check for OTA catalog first if storage service is available
        var data: Data
        var catalogSource: CatalogUpdatePreferences.CatalogSource = .bundled

        if let storageService = catalogStorageService,
           let otaData = await storageService.loadCurrentCatalog() {
            log.info("📥 Loading catalog from OTA download")
            data = otaData
            catalogSource = .downloaded
        } else {
            log.info("📦 Loading catalog from bundled JSON")
            data = try jsonLoader.findCatalogJSONData()
            catalogSource = .bundled
        }

        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)

        // Update catalog source preference
        CatalogUpdatePreferences.shared.catalogSource = catalogSource
        
        log.info("Loaded \(catalogItems.count) items from JSON, beginning comparison and transformation")
        
        // Get existing items for comparison
        let existingItems = try await catalogService.getAllGlassItems()
        log.info("Found \(existingItems.count) existing GlassItems in database")
        
        // Compare and categorize items
        let comparisonResult = await compareAndCategorizeItems(
            jsonItems: catalogItems,
            existingItems: existingItems.map { $0.glassItem },
            options: options
        )
        
        log.info("Comparison complete: \(comparisonResult.toCreate.count) to create, \(comparisonResult.toUpdate.count) to update, \(comparisonResult.unchanged.count) unchanged")

        // Process creates and updates
        var results = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0, // Add this field if it doesn't exist
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )

        // If skipExistingItems is true, count all existing items as skipped and only process creates
        if options.skipExistingItems {
            // Process new items (creates) only
            if !comparisonResult.toCreate.isEmpty {
                log.info("Creating \(comparisonResult.toCreate.count) new items (skip mode)")
                let createResults = try await processCreates(comparisonResult.toCreate, options: options)
                results.merge(createResults)
            }

            // Count all existing items (unchanged + toUpdate) as skipped
            results.itemsSkipped = comparisonResult.unchanged.count + comparisonResult.toUpdate.count
            log.info("Skipped \(results.itemsSkipped) existing items (skip mode enabled)")
        } else {
            // Normal processing: create new, update changed, sync tags for unchanged

            // Process new items (creates)
            if !comparisonResult.toCreate.isEmpty {
                log.info("Creating \(comparisonResult.toCreate.count) new items")
                let createResults = try await processCreates(comparisonResult.toCreate, options: options)
                results.merge(createResults)
            }

            // Process updated items
            if !comparisonResult.toUpdate.isEmpty {
                log.info("Updating \(comparisonResult.toUpdate.count) changed items")
                let updateResults = try await processUpdates(comparisonResult.toUpdate, options: options)
                results.itemsUpdated = updateResults.itemsUpdated
                results.itemsFailed += updateResults.itemsFailed
            }

            // Sync tags for unchanged items (they may have tag changes even if glass item unchanged)
            if !comparisonResult.unchanged.isEmpty {
                log.info("Syncing tags for \(comparisonResult.unchanged.count) unchanged items")
                let tagSyncResults = try await syncTagsForUnchangedItems(comparisonResult.unchanged, jsonItems: catalogItems, options: options)
                results.itemsUpdated += tagSyncResults.itemsUpdated
                results.itemsFailed += tagSyncResults.itemsFailed

                // Count truly unchanged items (no glass item changes AND no tag changes) as skipped
                let unchangedCount = comparisonResult.unchanged.count
                let tagsChangedCount = tagSyncResults.itemsUpdated
                results.itemsSkipped = unchangedCount - tagsChangedCount - tagSyncResults.itemsFailed
            } else {
                results.itemsSkipped = 0
            }
        }
        
        // Log final results
        logLoadingResults(results)

        // Save checksum and catalog data version after successful load (only if no critical errors)
        if results.itemsFailed == 0 || results.itemsCreated > 0 || results.itemsUpdated > 0 {
            do {
                try saveJSONChecksum()
                try saveCatalogDataVersion()
            } catch {
                log.warning("Failed to save JSON checksum/version: \(error.localizedDescription)")
            }
        }

        return results
    }

    /// Load glass items from raw JSON data (for OTA updates)
    /// - Parameters:
    ///   - data: Raw JSON data
    ///   - options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadGlassItemsFromData(_ data: Data, options: LoadingOptions = .default) async throws -> GlassItemLoadingResult {
        log.info("Starting GlassItem data loading from provided data with options: \(String(describing: options))")

        // Decode JSON data
        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)

        log.info("Loaded \(catalogItems.count) items from data, beginning comparison and transformation")

        // Get existing items for comparison
        let existingItems = try await catalogService.getAllGlassItems()
        log.info("Found \(existingItems.count) existing GlassItems in database")

        // Compare and categorize items
        let comparisonResult = await compareAndCategorizeItems(
            jsonItems: catalogItems,
            existingItems: existingItems.map { $0.glassItem },
            options: options
        )

        log.info("Comparison complete: \(comparisonResult.toCreate.count) to create, \(comparisonResult.toUpdate.count) to update, \(comparisonResult.unchanged.count) unchanged")

        // Process creates and updates
        var results = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )

        // Process new items (creates)
        if !comparisonResult.toCreate.isEmpty {
            log.info("Creating \(comparisonResult.toCreate.count) new items")
            let createResults = try await processCreates(comparisonResult.toCreate, options: options)
            results.merge(createResults)
        }

        // Process updated items
        if !comparisonResult.toUpdate.isEmpty {
            log.info("Updating \(comparisonResult.toUpdate.count) changed items")
            let updateResults = try await processUpdates(comparisonResult.toUpdate, options: options)
            results.itemsUpdated = updateResults.itemsUpdated
            results.itemsFailed += updateResults.itemsFailed
        }

        // Sync tags for unchanged items
        if !comparisonResult.unchanged.isEmpty {
            log.info("Syncing tags for \(comparisonResult.unchanged.count) unchanged items")
            let tagSyncResults = try await syncTagsForUnchangedItems(comparisonResult.unchanged, jsonItems: catalogItems, options: options)
            results.itemsUpdated += tagSyncResults.itemsUpdated
            results.itemsFailed += tagSyncResults.itemsFailed
        }

        // Count unchanged items as skipped
        results.itemsSkipped = comparisonResult.unchanged.count

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
        try await validator.validateJSONData()
    }
    
    // MARK: - Private Implementation
    
    /// Transform a single CatalogItemData to GlassItemCreationRequest (delegated to processor)
    private func transformSingleItemToRequest(
        _ catalogItem: CatalogItemData,
        options: LoadingOptions
    ) async -> GlassItemCreationRequest {
        return await processor.transformToRequest(catalogItem, options: options)
    }
    
    /// Process a batch of creation requests, handling both creates and updates
    private func processBatch(
        _ batch: [GlassItemCreationRequest],
        options: LoadingOptions
    ) async throws -> GlassItemLoadingResult {
        var result = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )
        
        // Process each item individually to handle creates vs updates
        for request in batch {
            do {
                let naturalKey = request.customNaturalKey ?? "unknown"
                
                // CRITICAL: Check if item already exists by stable_id (primary identifier)
                // DO NOT match by item_stable_id, manufacturer_url, or other fields
                let allItems = try await catalogService.getAllGlassItems()
                if let existingItem = allItems.first(where: { $0.glassItem.stable_id == naturalKey }) {
                    // Item exists - check if it needs updating
                    if try await shouldUpdateItem(existingItem.glassItem, withRequest: request) {
                        let updatedItem = try await updateExistingItem(existingItem.glassItem, withRequest: request)
                        result.successfulItems.append(updatedItem)
                        result.itemsUpdated += 1
                        log.debug("Updated existing item: \(naturalKey)")
                    } else {
                        // No update needed, count as skipped
                        result.successfulItems.append(existingItem)
                        result.itemsSkipped += 1
                        log.debug("Skipped unchanged item: \(naturalKey)")
                    }
                } else {
                    // Item doesn't exist - create new
                    let glassItem = GlassItemModel(
                        stable_id: naturalKey,
                        name: request.name,
                        sku: request.sku,
                        manufacturer: request.manufacturer,
                        mfr_notes: request.mfr_notes,
                        coe: request.coe,
                        url: request.url,
                        mfr_status: request.mfr_status,
                        image_url: request.image_url,
                        image_path: request.image_path
                    )
                    
                    let createdItem = try await catalogService.createGlassItem(
                        glassItem,
                        initialInventory: request.initialInventory,
                        tags: request.tags
                    )
                    
                    result.successfulItems.append(createdItem)
                    result.itemsCreated += 1
                }
                
            } catch {
                let failedItem = FailedGlassItem(
                    originalData: processor.catalogItemFromRequest(request),
                    error: error,
                    failureReason: error.localizedDescription
                )
                result.failedItems.append(failedItem)
                result.itemsFailed += 1
                log.error("Failed to process item: \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
    /// Check if an existing item needs to be updated based on the request
    private func shouldUpdateItem(_ existingItem: GlassItemModel, withRequest request: GlassItemCreationRequest) async throws -> Bool {
        // Compare key fields to see if they've changed
        return existingItem.name != request.name ||
               existingItem.sku != request.sku ||
               existingItem.manufacturer != request.manufacturer ||
               existingItem.mfr_notes != request.mfr_notes ||
               existingItem.coe != request.coe ||
               existingItem.url != request.url ||
               existingItem.mfr_status != request.mfr_status ||
               existingItem.image_url != request.image_url ||
               existingItem.image_path != request.image_path
    }
    
    /// Update an existing glass item with new data from the request
    private func updateExistingItem(_ existingItem: GlassItemModel, withRequest request: GlassItemCreationRequest) async throws -> CompleteInventoryItemModel {
        let updatedGlassItem = GlassItemModel(
            stable_id: existingItem.stable_id,
            name: request.name,
            sku: request.sku,
            manufacturer: request.manufacturer,
            mfr_notes: request.mfr_notes,
            coe: request.coe,
            url: request.url,
            mfr_status: request.mfr_status,
            image_url: request.image_url,
            image_path: request.image_path
        )
        
        // Update the item through the catalog service
        _ = try await catalogService.updateGlassItem(
            stableId: existingItem.stable_id,
            updatedGlassItem: updatedGlassItem,
            updatedTags: request.tags
        )

        // Get the complete item with inventory to return
        let allItems = try await catalogService.getAllGlassItems()
        return allItems.first { $0.glassItem.stable_id == existingItem.stable_id }!
    }

    // MARK: - Extraction Helpers (delegated to processor)
    // Note: Extraction logic moved to CatalogDataProcessor for reuse

    /// Log the final loading results
    private func logLoadingResults(_ result: GlassItemLoadingResult) {
        log.info("=== GlassItem Loading Results ===")
        log.info("Items Created: \(result.itemsCreated)")
        log.info("Items Updated: \(result.itemsUpdated)")
        log.info("Items Failed: \(result.itemsFailed)")
        log.info("Items Skipped: \(result.itemsSkipped)")
        log.info("Batch Errors: \(result.batchErrors.count)")
        
        if !result.failedItems.isEmpty {
            log.warning("Failed items:")
            for (index, failed) in result.failedItems.prefix(5).enumerated() {
                let code = failed.originalData.code ?? "NO_CODE"
                log.warning("  \(index + 1). \(failed.originalData.name) (\(code)): \(failed.failureReason)")
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

// MARK: - Comparison and Update Support
// Note: Result models moved to GlassItemDataLoadingModels.swift

extension GlassItemDataLoadingService {
    
    // MARK: - Comparison Methods
    
    /// Compare JSON items with existing GlassItems and categorize them
    private func compareAndCategorizeItems(
        jsonItems: [CatalogItemData],
        existingItems: [GlassItemModel],
        options: LoadingOptions
    ) async -> ComparisonResult {
        
        // CRITICAL: Create lookup dictionary for existing items by stable_id (primary identifier)
        // DO NOT use item_stable_id, manufacturer_url, or other fields as dictionary keys
        let existingByKey = Dictionary(uniqueKeysWithValues:
            existingItems.map { ($0.stable_id, $0) }
        )
        
        var toCreate: [CatalogItemData] = []
        var toUpdate: [ItemUpdatePair] = []
        var unchanged: [GlassItemModel] = []
        
        for jsonItem in jsonItems {
            // Generate natural key for this JSON item (same logic as in transform method)
            let naturalKey = generateNaturalKeyFromCatalogItem(from: jsonItem)
            
            if let existingItem = existingByKey[naturalKey] {
                // Item exists - check if it needs updating
                let differences = compareItems(existing: existingItem, jsonItem: jsonItem)
                
                if differences.isEmpty {
                    unchanged.append(existingItem)
                    log.debug("Item \(naturalKey) unchanged")
                } else {
                    let updatePair = ItemUpdatePair(
                        existing: existingItem,
                        updated: jsonItem,
                        differences: differences
                    )
                    toUpdate.append(updatePair)
                    log.info("Item \(naturalKey) needs update: \(differences.joined(separator: ", "))")
                }
            } else {
                // Item doesn't exist - needs to be created
                toCreate.append(jsonItem)
            }
        }
        
        return ComparisonResult(
            toCreate: toCreate,
            toUpdate: toUpdate,
            unchanged: unchanged
        )
    }
    
    /// Compare an existing GlassItem with JSON data to detect changes
    private func compareItems(existing: GlassItemModel, jsonItem: CatalogItemData) -> [String] {
        var differences: [String] = []

        // Compare basic properties
        if existing.name != jsonItem.name {
            differences.append("name: '\(existing.name)' -> '\(jsonItem.name)'")
        }

        let existingNotes = existing.mfr_notes ?? ""
        let newNotes = jsonItem.manufacturer_description ?? ""
        if existingNotes != newNotes {
            differences.append("mfr_notes: '\(existingNotes)' -> '\(newNotes)'")
        }

        // Extract manufacturer from code (as we do when creating/updating items)
        // Compare with existing manufacturer (both lowercased for consistency)
        let existingManufacturer = existing.manufacturer.lowercased()
        let newManufacturer = processor.extractManufacturer(from: jsonItem).lowercased()
        if existingManufacturer != newManufacturer {
            differences.append("manufacturer: '\(existing.manufacturer)' -> '\(processor.extractManufacturer(from: jsonItem))'")
        }

        let existingCOE = existing.coe
        let newCOE = processor.extractCOE(from: jsonItem)
        if existingCOE != newCOE {
            differences.append("coe: '\(existingCOE)' -> '\(newCOE)'")
        }

        // Compare URLs
        let existingURL = existing.url ?? ""
        let newURL = jsonItem.manufacturer_url ?? ""
        if existingURL != newURL {
            differences.append("url: '\(existingURL)' -> '\(newURL)'")
        }

        // Compare image URLs
        let existingImageURL = existing.image_url ?? ""
        let newImageURL = jsonItem.image_url ?? ""
        if existingImageURL != newImageURL {
            differences.append("image_url: '\(existingImageURL)' -> '\(newImageURL)'")
        }

        // Compare image paths
        let existingImagePath = existing.image_path ?? ""
        let newImagePath = jsonItem.image_path ?? ""
        if existingImagePath != newImagePath {
            differences.append("image_path: '\(existingImagePath)' -> '\(newImagePath)'")
        }

        return differences
    }
    
    /// Generate natural key from CatalogItemData (delegated to processor)
    /// CRITICAL: This always prefers stable_id from JSON (the primary identifier).
    /// DO NOT use item_stable_id, manufacturer_url, or other fields for identification.
    private func generateNaturalKeyFromCatalogItem(from item: CatalogItemData) -> String {
        return processor.generateNaturalKey(from: item)
    }
    
    // MARK: - Processing Methods
    
    /// Process items that need to be created (delegates to existing logic)
    private func processCreates(_ items: [CatalogItemData], options: LoadingOptions) async throws -> GlassItemLoadingResult {
        var results = GlassItemLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: [],
            batchErrors: []
        )

        let batches = stride(from: 0, to: items.count, by: options.batchSize).map {
            Array(items[$0..<min($0 + options.batchSize, items.count)])
        }

        for (_, batch) in batches.enumerated() {
            for catalogItem in batch {
                do {
                    // Transform to creation request
                    let request = await transformSingleItemToRequest(catalogItem, options: options)
                    let naturalKey = request.customNaturalKey ?? "unknown"

                    // Create the glass item
                    let glassItem = GlassItemModel(
                        stable_id: naturalKey,
                        name: request.name,
                        sku: request.sku,
                        manufacturer: request.manufacturer,
                        mfr_notes: request.mfr_notes,
                        coe: request.coe,
                        url: request.url,
                        mfr_status: request.mfr_status,
                        image_url: request.image_url,
                        image_path: request.image_path
                    )

                    let createdItem = try await catalogService.createGlassItem(
                        glassItem,
                        initialInventory: request.initialInventory,
                        tags: request.tags
                    )

                    results.successfulItems.append(createdItem)
                    results.itemsCreated += 1

                } catch {
                    let failedItem = FailedGlassItem(
                        originalData: catalogItem,
                        error: error,
                        failureReason: error.localizedDescription
                    )
                    results.failedItems.append(failedItem)
                    results.itemsFailed += 1
                    log.error("Failed to create item: \(error.localizedDescription)")
                }
            }

            // Brief pause between batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return results
    }
    
    /// Process items that need to be updated
    private func processUpdates(_ updates: [ItemUpdatePair], options: LoadingOptions) async throws -> UpdateResult {
        var itemsUpdated = 0
        var itemsFailed = 0
        var failedUpdates: [FailedItem] = []

        // Process updates in batches
        let batches = stride(from: 0, to: updates.count, by: options.batchSize).map {
            Array(updates[$0..<min($0 + options.batchSize, updates.count)])
        }

        for (batchIndex, batch) in batches.enumerated() {
            log.info("Processing update batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items)")

            for updatePair in batch {
                do {
                    // Create updated GlassItemModel from JSON data
                    let updatedItem = createUpdatedGlassItem(from: updatePair)

                    // Extract tags from JSON (same as we do for creates)
                    let updatedTags = processor.extractTags(from: updatePair.updated)

                    // Update the item using catalogService, passing tags to sync with JSON
                    _ = try await catalogService.updateGlassItem(
                        stableId: updatedItem.stable_id,
                        updatedGlassItem: updatedItem,
                        updatedTags: updatedTags
                    )

                    itemsUpdated += 1
//                    log.info("Updated item \(updatedItem.stable_id): \(updatePair.differences.joined(separator: ", "))")

                } catch {
                    itemsFailed += 1
                    let failedItem = FailedItem(
                        originalData: updatePair.updated,
                        failureReason: "Update failed: \(error.localizedDescription)"
                    )
                    failedUpdates.append(failedItem)
                    log.error("Failed to update item \(updatePair.existing.stable_id): \(error)")
                }
            }

            // Brief pause between update batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return UpdateResult(
            itemsUpdated: itemsUpdated,
            itemsFailed: itemsFailed,
            failedUpdates: failedUpdates
        )
    }
    
    /// Sync tags for unchanged items (glass item fields unchanged but tags may have changed)
    /// IMPORTANT: This method exists because compareItems() only checks glass item fields
    /// (name, manufacturer, COE, etc.), NOT tags. This means items marked as "unchanged"
    /// still need their tags synced to match the JSON file exactly. Without this method,
    /// old auto-generated tags (manufacturer, COE, stock_type) would never be removed.
    private func syncTagsForUnchangedItems(
        _ unchangedItems: [GlassItemModel],
        jsonItems: [CatalogItemData],
        options: LoadingOptions
    ) async throws -> UpdateResult {
        var itemsUpdated = 0
        var itemsFailed = 0
        var failedUpdates: [FailedItem] = []

        // Create lookup dictionary for JSON items by natural key
        var jsonByKey: [String: CatalogItemData] = [:]
        for jsonItem in jsonItems {
            let naturalKey = generateNaturalKeyFromCatalogItem(from: jsonItem)
            jsonByKey[naturalKey] = jsonItem
        }

        // Process in batches to avoid overwhelming the system
        let batches = stride(from: 0, to: unchangedItems.count, by: options.batchSize).map {
            Array(unchangedItems[$0..<min($0 + options.batchSize, unchangedItems.count)])
        }

        for (batchIndex, batch) in batches.enumerated() {
            for glassItem in batch {
                guard let jsonItem = jsonByKey[glassItem.stable_id] else {
                    continue // Skip if no matching JSON item
                }

                do {
                    // Extract tags from JSON (same as we do for creates and updates)
                    var updatedTags: [String] = []
                    if options.enableTagExtraction {
                        updatedTags.append(contentsOf: processor.extractTags(from: jsonItem))
                    }
                    if options.enableSynonymTags {
                        updatedTags.append(contentsOf: processor.extractSynonymTags(from: jsonItem))
                    }

                    // Get existing tags to check if they changed
                    let completeItem = try await catalogService.getGlassItemByNaturalKey(glassItem.stable_id)
                    let existingTags = completeItem?.tags.map { $0.lowercased() }.sorted() ?? []
                    let newTags = updatedTags.map { $0.lowercased() }.sorted()

                    // Only update if tags have changed
                    if existingTags != newTags {
                        // Sync tags using setTags (replaces all tags to match JSON exactly)
                        // NOTE: We pass the same glassItem because the glass item fields haven't changed
                        _ = try await catalogService.updateGlassItem(
                            stableId: glassItem.stable_id,
                            updatedGlassItem: glassItem, // No changes to glass item itself
                            updatedTags: updatedTags
                        )

                        itemsUpdated += 1
                        log.debug("Updated tags for item \(glassItem.stable_id)")
                    }
                } catch {
                    itemsFailed += 1
                    let failedItem = FailedItem(
                        originalData: jsonItem,
                        failureReason: "Tag sync failed: \(error.localizedDescription)"
                    )
                    failedUpdates.append(failedItem)
                    log.error("Failed to sync tags for item \(glassItem.stable_id): \(error)")
                }
            }

            // Brief pause between batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return UpdateResult(
            itemsUpdated: itemsUpdated,
            itemsFailed: itemsFailed,
            failedUpdates: failedUpdates
        )
    }

    /// Create an updated GlassItemModel by merging existing item with JSON changes
    private func createUpdatedGlassItem(from updatePair: ItemUpdatePair) -> GlassItemModel {
        let existing = updatePair.existing
        let jsonItem = updatePair.updated

        return GlassItemModel(
            stable_id: existing.stable_id,
            name: jsonItem.name,
            sku: processor.extractSKU(from: jsonItem), // Update SKU from JSON (can be nil for manufacturers without SKUs)
            manufacturer: processor.extractManufacturer(from: jsonItem), // Extract abbreviation from code
            mfr_notes: jsonItem.manufacturer_description,
            coe: processor.extractCOE(from: jsonItem),
            url: jsonItem.manufacturer_url,
            mfr_status: existing.mfr_status, // Keep existing status
            image_url: jsonItem.image_url,
            image_path: jsonItem.image_path
        )
    }
}
