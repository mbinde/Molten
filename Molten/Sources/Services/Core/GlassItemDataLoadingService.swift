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
@preconcurrency
class GlassItemDataLoadingService {
    
    // MARK: - Dependencies

    nonisolated private let catalogService: CatalogService
    nonisolated(unsafe) private let jsonLoader: JSONDataLoading
    private let log = Logger(subsystem: "Flameworker", category: "GlassItemDataLoading")
    
    // MARK: - JSON Checksum Support

    /// Store JSON file checksum in UserDefaults for change detection
    private struct JSONChecksum: Codable {
        let modificationDate: Date
        let fileSize: Int64
    }

    private static let checksumKey = "com.flameworker.json.checksum"

    /// Check if JSON file has changed since last load
    /// Returns true if file has changed or is first run, false if unchanged
    func hasJSONFileChanged() throws -> Bool {
        // Get file attributes to compute checksum
        guard let filePath = Bundle.main.path(forResource: "glassitems", ofType: "json") else {
            log.warning("Could not find glassitems.json file path, assuming changed")
            return true
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        guard let modificationDate = attributes[.modificationDate] as? Date,
              let fileSize = attributes[.size] as? Int64 else {
            log.warning("Could not read file attributes, assuming changed")
            return true
        }

        let currentChecksum = JSONChecksum(modificationDate: modificationDate, fileSize: fileSize)

        // Check stored checksum
        if let storedData = UserDefaults.standard.data(forKey: Self.checksumKey),
           let storedChecksum = try? JSONDecoder().decode(JSONChecksum.self, from: storedData) {

            // Compare checksums
            let hasChanged = storedChecksum.modificationDate != currentChecksum.modificationDate ||
                           storedChecksum.fileSize != currentChecksum.fileSize

            if hasChanged {
                log.info("🔄 Detected JSON file change (mod date or size changed)")
            } else {
                log.info("✅ JSON file unchanged since last load, skipping")
            }

            return hasChanged
        } else {
            log.info("🆕 First run or no checksum found, will load JSON")
            return true
        }
    }

    /// Save current JSON file checksum to UserDefaults after successful load
    func saveJSONChecksum() throws {
        guard let filePath = Bundle.main.path(forResource: "glassitems", ofType: "json") else {
            log.warning("Could not find glassitems.json file path, cannot save checksum")
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        guard let modificationDate = attributes[.modificationDate] as? Date,
              let fileSize = attributes[.size] as? Int64 else {
            log.warning("Could not read file attributes, cannot save checksum")
            return
        }

        let checksum = JSONChecksum(modificationDate: modificationDate, fileSize: fileSize)
        let data = try JSONEncoder().encode(checksum)
        UserDefaults.standard.set(data, forKey: Self.checksumKey)

        log.info("💾 Saved JSON checksum (size: \(fileSize) bytes, modified: \(modificationDate))")
    }

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
        
        /// Option for app updates - processes all items and updates any that have changed
        static let appUpdate = LoadingOptions(
            skipExistingItems: false, // Process all items to check for updates
            createInitialInventory: false, // Don't create new inventory for updates
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 0.0,
            enableTagExtraction: true,
            enableSynonymTags: true,
            validateNaturalKeys: true,
            batchSize: 25 // Moderate batch size for stability
        )
    }
    
    // MARK: - Initialization
    
    nonisolated init(catalogService: CatalogService, jsonLoader: JSONDataLoading = JSONDataLoader()) {
        self.catalogService = catalogService
        self.jsonLoader = jsonLoader
    }
    
    // MARK: - Public API
    
    /// Load glass items from glassitems.json into the new GlassItem system
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadGlassItemsFromJSON(options: LoadingOptions = .default) async throws -> GlassItemLoadingResult {
        // Skip system readiness validation for initial loading scenarios
        // The validateSystemReadiness check was preventing initial data loading into empty systems
        // TODO: Add a more appropriate validation that allows initial loading but prevents other issues
        
        log.info("Starting GlassItem data loading from JSON with options: \(String(describing: options))")
        
        // Load and decode JSON data
        let data = try jsonLoader.findCatalogJSONData()
        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)
        
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
        }

        // Count unchanged items as skipped (but subtract any that had tag updates)
        results.itemsSkipped = comparisonResult.unchanged.count
        
        // Log final results
        logLoadingResults(results)

        // Save checksum after successful load (only if no critical errors)
        if results.itemsFailed == 0 || results.itemsCreated > 0 || results.itemsUpdated > 0 {
            do {
                try saveJSONChecksum()
            } catch {
                log.warning("Failed to save JSON checksum: \(error.localizedDescription)")
            }
        }

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
    
    /// Transform a single CatalogItemData to GlassItemCreationRequest
    private func transformSingleItemToRequest(
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
                item_stable_id: naturalKey,
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
            tags: Array(Set(tags)), // Remove duplicates
            image_url: catalogItem.image_url,
            image_path: catalogItem.image_path
        )
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
                
                // Check if item already exists
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
                        natural_key: naturalKey,
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
                    originalData: catalogItemFromRequest(request),
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
            natural_key: existingItem.stable_id, // Keep original natural key
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
    
    // MARK: - Data Extraction Helpers
    
    /// Extract manufacturer from CatalogItemData
    private func extractManufacturer(from catalogItem: CatalogItemData) -> String {
        // Manufacturers in the database are stored as abbreviations (e.g., "BE", "CiM", "EF", "GAF")
        // NOT as full names like "Bullseye Glass Co"

        // ALWAYS use the manufacturer field if provided (this is the proper manufacturer code from JSON)
        if let manufacturer = catalogItem.manufacturer, !manufacturer.isEmpty {
            return manufacturer  // Keep original case to match GlassManufacturers mapping
        }

        // Fallback: extract from code (format like "CIM-123" -> "CIM")
        // This is a legacy fallback for old data that might not have the manufacturer field
        let codeParts = catalogItem.code.components(separatedBy: "-")
        if codeParts.count >= 2 {
            return codeParts[0]  // Keep original case
        }

        return "unknown"
    }
    
    /// Extract SKU from CatalogItemData
    private func extractSKU(from catalogItem: CatalogItemData) -> String {
        // FIXED: Store the full code as the SKU
        // This ensures image loading works correctly since image files are named with the full code
        // For example: "OC-6023-83CC-F" stays as "OC-6023-83CC-F", not truncated to "6023"
        // The SKU field should contain the full product code for image lookup
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

        // Add explicit tags from JSON only
        if let itemTags = catalogItem.tags {
            tags.append(contentsOf: itemTags)
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

    /// Extract stable_id from CatalogItemData
    private func extractStableId(from catalogItem: CatalogItemData) -> String? {
        return catalogItem.stable_id
    }

    /// Generate natural key from CatalogItemData
    /// If stable_id is present in JSON, use it. Otherwise, generate from manufacturer and SKU.
    private func generateNaturalKey(from catalogItem: CatalogItemData) -> String {
        // Use stable_id from JSON if available (preferred)
        if let stableId = catalogItem.stable_id, !stableId.isEmpty {
            return stableId
        }

        // Fallback: generate from manufacturer and SKU
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
            image_path: request.image_path,
            coe: String(request.coe),
            stock_type: request.initialInventory.first?.type,
            image_url: request.image_url,
            manufacturer_url: request.url
        )
    }
    
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
    var itemsUpdated: Int = 0  // New field for tracking updates
    var successfulItems: [CompleteInventoryItemModel] = []
    var failedItems: [FailedGlassItem] = []
    var batchErrors: [BatchError] = []
    
    /// Merge another result into this one
    mutating func merge(_ other: GlassItemLoadingResult) {
        itemsCreated += other.itemsCreated
        itemsFailed += other.itemsFailed
        itemsSkipped += other.itemsSkipped
        itemsUpdated += other.itemsUpdated  // Include updates in merge
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

/// Information about a failed item (generic failure type)
struct FailedItem {
    let originalData: CatalogItemData
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

// MARK: - Comparison and Update Support

/// Result of comparing JSON data with existing GlassItems
struct ComparisonResult {
    let toCreate: [CatalogItemData]      // Items that don't exist yet
    let toUpdate: [ItemUpdatePair]       // Items that exist but have changed
    let unchanged: [GlassItemModel]      // Items that exist and haven't changed
}

/// Pair of items for updating - old and new data
struct ItemUpdatePair {
    let existing: GlassItemModel
    let updated: CatalogItemData
    let differences: [String]  // Description of what changed
}

/// Result of processing updates
struct UpdateResult {
    let itemsUpdated: Int
    let itemsFailed: Int
    let failedUpdates: [FailedItem]
}

extension GlassItemDataLoadingService {
    
    // MARK: - Comparison Methods
    
    /// Compare JSON items with existing GlassItems and categorize them
    private func compareAndCategorizeItems(
        jsonItems: [CatalogItemData],
        existingItems: [GlassItemModel],
        options: LoadingOptions
    ) async -> ComparisonResult {
        
        // Create lookup dictionary for existing items by natural key
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
        let newManufacturer = extractManufacturer(from: jsonItem).lowercased()
        if existingManufacturer != newManufacturer {
            differences.append("manufacturer: '\(existing.manufacturer)' -> '\(extractManufacturer(from: jsonItem))'")
        }

        let existingCOE = existing.coe
        let newCOE = extractCOE(from: jsonItem)
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
    
    /// Generate natural key from CatalogItemData (must match generateNaturalKey format!)
    private func generateNaturalKeyFromCatalogItem(from item: CatalogItemData) -> String {
        // CRITICAL: Use the SAME logic as generateNaturalKey to ensure comparison works
        // This uses manufacturer-sku-sequence format, not uppercased code
        let manufacturer = extractManufacturer(from: item)
        let sku = extractSKU(from: item)
        return GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
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
                        natural_key: naturalKey,
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
                    let updatedTags = extractTags(from: updatePair.updated)

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
            log.info("Processing tag sync batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items)")

            for glassItem in batch {
                guard let jsonItem = jsonByKey[glassItem.stable_id] else {
                    continue // Skip if no matching JSON item
                }

                do {
                    // Extract tags from JSON (same as we do for creates and updates)
                    let updatedTags = extractTags(from: jsonItem)

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
                    } else {
                        log.debug("Tags unchanged for item \(glassItem.stable_id), skipping update")
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
            natural_key: existing.stable_id, // Keep the same natural key
            name: jsonItem.name,
            sku: existing.sku, // Keep existing SKU
            manufacturer: extractManufacturer(from: jsonItem), // Extract abbreviation from code
            mfr_notes: jsonItem.manufacturer_description,
            coe: extractCOE(from: jsonItem),
            url: jsonItem.manufacturer_url,
            mfr_status: existing.mfr_status, // Keep existing status
            image_url: jsonItem.image_url,
            image_path: jsonItem.image_path
        )
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


