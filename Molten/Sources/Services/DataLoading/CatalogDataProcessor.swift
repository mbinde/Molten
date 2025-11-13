//
//  CatalogDataProcessor.swift
//  Molten
//
//  Created by Assistant on 2025-11-12.
//  Processes and transforms catalog data for importing
//

import Foundation
import OSLog

/// Processes catalog data - transforms, validates, creates, and updates items
final class CatalogDataProcessor: Sendable {

    // MARK: - Properties

    nonisolated private let catalogService: CatalogService

    // MARK: - Initialization

    /// Initialize processor with catalog service
    /// - Parameter catalogService: Service for catalog operations
    nonisolated init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }

    // MARK: - Public API

    /// Transform a single CatalogItemData to GlassItemCreationRequest
    /// - Parameters:
    ///   - catalogItem: Raw catalog item data from JSON
    ///   - options: Loading options controlling behavior
    /// - Returns: Creation request ready for processing
    func transformToRequest(
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
    /// - Parameters:
    ///   - batch: Batch of creation requests to process
    ///   - options: Loading options controlling behavior
    /// - Returns: Result summarizing creates, updates, failures
    /// - Throws: If processing fails
    func processBatch(
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
                        Logger.dataLoading.debug("Updated existing item: \(naturalKey)")
                    } else {
                        // No update needed, count as skipped
                        result.successfulItems.append(existingItem)
                        result.itemsSkipped += 1
                        Logger.dataLoading.debug("Skipped unchanged item: \(naturalKey)")
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
                    originalData: catalogItemFromRequest(request),
                    error: error,
                    failureReason: error.localizedDescription
                )
                result.failedItems.append(failedItem)
                result.itemsFailed += 1
                Logger.dataLoading.error("Failed to process item: \(error.localizedDescription)")
            }
        }

        return result
    }

    // MARK: - Update Handling

    /// Check if an existing item needs to be updated based on the request
    /// - Parameters:
    ///   - existingItem: Current item in catalog
    ///   - request: New data from JSON
    /// - Returns: true if item has changes requiring update
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
    /// - Parameters:
    ///   - existingItem: Current item in catalog
    ///   - request: New data from JSON
    /// - Returns: Updated complete item model
    /// - Throws: If update fails
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

    // MARK: - Data Extraction Helpers (public for service reuse)

    /// Extract manufacturer abbreviation from catalog item
    func extractManufacturer(from catalogItem: CatalogItemData) -> String {
        // Manufacturers in the database are stored as abbreviations (e.g., "BE", "CiM", "EF", "GAF")
        // NOT as full names like "Bullseye Glass Co"

        // ALWAYS use the manufacturer field if provided (this is the proper manufacturer code from JSON)
        if let manufacturer = catalogItem.manufacturer, !manufacturer.isEmpty {
            return manufacturer  // Keep original case to match GlassManufacturers mapping
        }

        // Fallback: extract from code (format like "CIM-123" -> "CIM")
        // This is a legacy fallback for old data that might not have the manufacturer field
        if let code = catalogItem.code {
            let codeParts = code.components(separatedBy: "-")
            if codeParts.count >= 2 {
                return codeParts[0]  // Keep original case
            }
        }

        return "unknown"
    }

    /// Extract SKU from CatalogItemData (returns nil if code is missing)
    func extractSKU(from catalogItem: CatalogItemData) -> String? {
        // Return the full code as the SKU if it exists
        // This ensures image loading works correctly since image files are named with the full code
        // For example: "OC-6023-83CC-F" stays as "OC-6023-83CC-F", not truncated to "6023"
        // Returns nil for manufacturers that don't use SKUs
        return catalogItem.code
    }

    /// Extract COE from CatalogItemData
    func extractCOE(from catalogItem: CatalogItemData) -> Int32 {
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
    func extractTags(from catalogItem: CatalogItemData) -> [String] {
        var tags: [String] = []

        // Add explicit tags from JSON only
        if let itemTags = catalogItem.tags {
            tags.append(contentsOf: itemTags)
        }

        return tags.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
               .filter { !$0.isEmpty }
    }

    /// Extract synonym-based tags from CatalogItemData
    func extractSynonymTags(from catalogItem: CatalogItemData) -> [String] {
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
    /// CRITICAL: stable_id is the primary identifier for glass items (6-character hash-based ID).
    /// This is used throughout the app to identify items, NOT old keys like item_stable_id
    /// or manufacturer_url.
    private func extractStableId(from catalogItem: CatalogItemData) -> String? {
        return catalogItem.stable_id
    }

    /// Generate natural key from CatalogItemData
    /// CRITICAL: This always prefers stable_id from JSON when available.
    /// The stable_id is the primary identifier (6-char hash from the scraper database).
    /// natural_key is now a legacy field that mirrors stable_id.
    /// DO NOT use item_stable_id, manufacturer_url, or other fields for identification.
    func generateNaturalKey(from catalogItem: CatalogItemData) -> String {
        // Use stable_id from JSON if available (preferred - this is the standard case)
        if let stableId = catalogItem.stable_id, !stableId.isEmpty {
            return stableId
        }

        // Fallback: generate a stable_id for very old data without one
        // stable_id is a 6-char hash, not a sequential key
        let manufacturer = extractManufacturer(from: catalogItem)
        let sku = extractSKU(from: catalogItem) ?? "NO_SKU"
        return String(format: "%06d", abs("\(manufacturer)-\(sku)".hashValue % 1000000))
    }

    /// Convert GlassItemCreationRequest back to CatalogItemData for error reporting
    /// - Parameter request: Creation request to convert
    /// - Returns: Catalog item data for error messages
    func catalogItemFromRequest(_ request: GlassItemCreationRequest) -> CatalogItemData {
        return CatalogItemData(
            id: nil,
            code: "\(request.manufacturer)-\(request.sku ?? "NO_SKU")",
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
}
