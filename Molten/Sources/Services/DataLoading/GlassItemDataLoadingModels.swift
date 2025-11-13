//
//  GlassItemDataLoadingModels.swift
//  Molten
//
//  Created by Assistant on 2025-11-12.
//  Data models and configuration for glass item data loading operations
//

import Foundation

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
