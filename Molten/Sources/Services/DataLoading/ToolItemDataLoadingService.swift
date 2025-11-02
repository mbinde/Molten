//
//  ToolItemDataLoadingService.swift
//  Molten
//
//  Service for loading tool data from JSON files into the ToolItem system
//

import Foundation
import OSLog

/// Service for loading data from JSON files into the ToolItem system
/// Handles transformation from JSON format to the normalized entity structure
/// Supports initial loading and bulk import operations
@preconcurrency
class ToolItemDataLoadingService {

    // MARK: - Dependencies

    nonisolated private let toolRepository: ToolItemRepository
    private let log = Logger(subsystem: "Molten", category: "ToolItemDataLoading")

    // MARK: - JSON Checksum Support

    /// Store JSON file checksum in UserDefaults for change detection
    private struct JSONChecksum: Codable {
        let modificationDate: Date
        let fileSize: Int64
    }

    private static let checksumKey = "com.molten.tools.json.checksum"

    /// Check if JSON file has changed since last load
    /// Returns true if file has changed or is first run, false if unchanged
    func hasJSONFileChanged(manufacturer: String) throws -> Bool {
        // Get file attributes to compute checksum
        guard let filePath = Bundle.main.path(forResource: "\(manufacturer)_tools", ofType: "json") else {
            log.warning("Could not find \(manufacturer)_tools.json file path, assuming changed")
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
        let checksumKeyForMfr = "\(Self.checksumKey).\(manufacturer)"
        if let storedData = UserDefaults.standard.data(forKey: checksumKeyForMfr),
           let storedChecksum = try? JSONDecoder().decode(JSONChecksum.self, from: storedData) {

            // Compare checksums
            let hasChanged = storedChecksum.modificationDate != currentChecksum.modificationDate ||
                           storedChecksum.fileSize != currentChecksum.fileSize

            if hasChanged {
                log.info("🔄 Detected JSON file change for \(manufacturer) (mod date or size changed)")
            } else {
                log.info("✅ JSON file unchanged for \(manufacturer) since last load, skipping")
            }

            return hasChanged
        } else {
            log.info("🆕 First run or no checksum found for \(manufacturer), will load JSON")
            return true
        }
    }

    /// Save current JSON file checksum to UserDefaults after successful load
    func saveJSONChecksum(manufacturer: String) throws {
        guard let filePath = Bundle.main.path(forResource: "\(manufacturer)_tools", ofType: "json") else {
            log.warning("Could not find \(manufacturer)_tools.json file path, cannot save checksum")
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
        let checksumKeyForMfr = "\(Self.checksumKey).\(manufacturer)"
        UserDefaults.standard.set(data, forKey: checksumKeyForMfr)

        log.info("💾 Saved JSON checksum for \(manufacturer) (size: \(fileSize) bytes, modified: \(modificationDate))")
    }

    // MARK: - Configuration

    /// Options for controlling the data loading behavior
    struct LoadingOptions {
        let skipExistingItems: Bool
        let validateNaturalKeys: Bool
        let batchSize: Int

        static let `default` = LoadingOptions(
            skipExistingItems: true,
            validateNaturalKeys: true,
            batchSize: 50
        )

        static let testing = LoadingOptions(
            skipExistingItems: false,
            validateNaturalKeys: true,
            batchSize: 10
        )

        /// Option for app updates - processes all items and updates any that have changed
        static let appUpdate = LoadingOptions(
            skipExistingItems: false,
            validateNaturalKeys: true,
            batchSize: 25
        )
    }

    // MARK: - Initialization

    nonisolated init(toolRepository: ToolItemRepository) {
        self.toolRepository = toolRepository
    }

    // MARK: - Public API

    /// Load tools from manufacturer JSON file
    /// - Parameter manufacturer: Manufacturer code (e.g., "taglia")
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadToolsFromJSON(manufacturer: String, options: LoadingOptions = .default) async throws -> ToolLoadingResult {
        log.info("Starting Tool data loading from JSON for manufacturer: \(manufacturer)")

        // Load and decode JSON data
        guard let data = loadJSONData(manufacturer: manufacturer) else {
            throw ToolItemDataLoadingError.fileNotFound(manufacturer)
        }

        let toolsData = try decodeToolsData(from: data)

        log.info("Loaded \(toolsData.tools.count) tools from JSON for \(manufacturer)")

        // Get existing items for comparison
        let existingItems = try await toolRepository.fetchItems(byManufacturer: manufacturer)
        log.info("Found \(existingItems.count) existing tools for \(manufacturer) in database")

        // Compare and categorize items
        let comparisonResult = compareAndCategorizeItems(
            jsonTools: toolsData.tools,
            existingItems: existingItems,
            manufacturer: manufacturer,
            options: options
        )

        log.info("Comparison complete: \(comparisonResult.toCreate.count) to create, \(comparisonResult.toUpdate.count) to update, \(comparisonResult.unchanged.count) unchanged")

        // Process creates and updates
        var results = ToolLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        // Process new items (creates)
        if !comparisonResult.toCreate.isEmpty {
            log.info("Creating \(comparisonResult.toCreate.count) new tools")
            let createResults = try await processCreates(
                comparisonResult.toCreate,
                manufacturer: manufacturer,
                manufacturerName: toolsData.manufacturer_name,
                options: options
            )
            results.merge(createResults)
        }

        // Process updated items
        if !comparisonResult.toUpdate.isEmpty {
            log.info("Updating \(comparisonResult.toUpdate.count) changed tools")
            let updateResults = try await processUpdates(comparisonResult.toUpdate, options: options)
            results.itemsUpdated = updateResults.itemsUpdated
            results.itemsFailed += updateResults.itemsFailed
        }

        // Count unchanged items as skipped
        results.itemsSkipped = comparisonResult.unchanged.count

        // Log final results
        logLoadingResults(results, manufacturer: manufacturer)

        // Save checksum after successful load (only if no critical errors)
        if results.itemsFailed == 0 || results.itemsCreated > 0 || results.itemsUpdated > 0 {
            do {
                try saveJSONChecksum(manufacturer: manufacturer)
            } catch {
                log.warning("Failed to save JSON checksum: \(error.localizedDescription)")
            }
        }

        return results
    }

    /// Load all tools from all manufacturer JSON files
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Combined results from all manufacturers
    func loadAllToolsFromJSON(options: LoadingOptions = .default) async throws -> ToolLoadingResult {
        log.info("Loading all tools from all manufacturer JSON files")

        var combinedResults = ToolLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        // List of all tool manufacturer files
        let manufacturers = ["taglia"] // Add more as they're added

        for manufacturer in manufacturers {
            do {
                let result = try await loadToolsFromJSON(manufacturer: manufacturer, options: options)
                combinedResults.merge(result)
            } catch {
                log.error("Failed to load tools for \(manufacturer): \(error.localizedDescription)")
            }
        }

        log.info("Completed loading all tools: \(combinedResults.itemsCreated) created, \(combinedResults.itemsUpdated) updated, \(combinedResults.itemsSkipped) skipped, \(combinedResults.itemsFailed) failed")

        return combinedResults
    }

    // MARK: - Private Implementation

    /// Load JSON data from bundle
    private func loadJSONData(manufacturer: String) -> Data? {
        guard let path = Bundle.main.path(forResource: "\(manufacturer)_tools", ofType: "json") else {
            log.error("Could not find \(manufacturer)_tools.json in bundle")
            return nil
        }

        do {
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            log.error("Failed to load JSON data: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decode tools data from JSON
    private func decodeToolsData(from data: Data) throws -> ToolsJSONData {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ToolsJSONData.self, from: data)
        } catch {
            log.error("Failed to decode tools JSON: \(error.localizedDescription)")
            throw ToolItemDataLoadingError.decodingFailed(error)
        }
    }

    /// Compare JSON tools with existing tools and categorize them
    private func compareAndCategorizeItems(
        jsonTools: [ToolJSONItem],
        existingItems: [ToolItemModel],
        manufacturer: String,
        options: LoadingOptions
    ) -> ToolComparisonResult {

        // Create lookup dictionary for existing items by SKU
        let existingBySKU = Dictionary(uniqueKeysWithValues:
            existingItems.compactMap { item in
                item.sku.map { ($0, item) }
            }
        )

        var toCreate: [ToolJSONItem] = []
        var toUpdate: [ToolUpdatePair] = []
        var unchanged: [ToolItemModel] = []

        for jsonTool in jsonTools {
            guard let sku = jsonTool.sku else {
                toCreate.append(jsonTool) // No SKU = always create
                continue
            }

            if let existingItem = existingBySKU[sku] {
                // Item exists - check if it needs updating
                let differences = compareItems(existing: existingItem, jsonItem: jsonTool)

                if differences.isEmpty {
                    unchanged.append(existingItem)
                } else {
                    let updatePair = ToolUpdatePair(
                        existing: existingItem,
                        updated: jsonTool,
                        differences: differences
                    )
                    toUpdate.append(updatePair)
                    log.info("Tool \(sku) needs update: \(differences.joined(separator: ", "))")
                }
            } else {
                // Item doesn't exist - needs to be created
                toCreate.append(jsonTool)
            }
        }

        return ToolComparisonResult(
            toCreate: toCreate,
            toUpdate: toUpdate,
            unchanged: unchanged
        )
    }

    /// Compare an existing tool with JSON data to detect changes
    private func compareItems(existing: ToolItemModel, jsonItem: ToolJSONItem) -> [String] {
        var differences: [String] = []

        // Compare basic properties
        if existing.name != jsonItem.name {
            differences.append("name: '\(existing.name)' -> '\(jsonItem.name)'")
        }

        // Compare status
        let existingStatus = existing.mfr_status
        let newStatus = jsonItem.status ?? "available"
        if existingStatus != newStatus {
            differences.append("status: '\(existingStatus)' -> '\(newStatus)'")
        }

        return differences
    }

    /// Process items that need to be created
    private func processCreates(
        _ tools: [ToolJSONItem],
        manufacturer: String,
        manufacturerName: String,
        options: LoadingOptions
    ) async throws -> ToolLoadingResult {
        var results = ToolLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        let batches = stride(from: 0, to: tools.count, by: options.batchSize).map {
            Array(tools[$0..<min($0 + options.batchSize, tools.count)])
        }

        for batch in batches {
            for jsonTool in batch {
                do {
                    // Generate stable_id
                    let stableId = try await toolRepository.generateNextNaturalKey(
                        manufacturer: manufacturer,
                        sku: jsonTool.sku
                    )

                    // Create tool item model
                    let toolItem = ToolItemModel(
                        stable_id: stableId,
                        name: jsonTool.name,
                        sku: jsonTool.sku,
                        manufacturer: manufacturer,
                        mfr_notes: jsonTool.category,
                        url: nil,
                        mfr_status: jsonTool.status ?? "available",
                        image_url: nil,
                        image_path: nil
                    )

                    let createdItem = try await toolRepository.createItem(toolItem)
                    results.successfulItems.append(createdItem)
                    results.itemsCreated += 1

                } catch {
                    let failedItem = FailedToolItem(
                        name: jsonTool.name,
                        sku: jsonTool.sku,
                        error: error,
                        failureReason: error.localizedDescription
                    )
                    results.failedItems.append(failedItem)
                    results.itemsFailed += 1
                    log.error("Failed to create tool: \(error.localizedDescription)")
                }
            }

            // Brief pause between batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return results
    }

    /// Process items that need to be updated
    private func processUpdates(_ updates: [ToolUpdatePair], options: LoadingOptions) async throws -> ToolUpdateResult {
        var itemsUpdated = 0
        var itemsFailed = 0

        // Process updates in batches
        let batches = stride(from: 0, to: updates.count, by: options.batchSize).map {
            Array(updates[$0..<min($0 + options.batchSize, updates.count)])
        }

        for (batchIndex, batch) in batches.enumerated() {
            log.info("Processing update batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items)")

            for updatePair in batch {
                do {
                    // Create updated ToolItemModel from JSON data
                    let updatedItem = ToolItemModel(
                        stable_id: updatePair.existing.stable_id,
                        name: updatePair.updated.name,
                        sku: updatePair.updated.sku,
                        manufacturer: updatePair.existing.manufacturer,
                        mfr_notes: updatePair.updated.category,
                        url: updatePair.existing.url,
                        mfr_status: updatePair.updated.status ?? "available",
                        image_url: updatePair.existing.image_url,
                        image_path: updatePair.existing.image_path
                    )

                    // Update the item
                    _ = try await toolRepository.updateItem(updatedItem)
                    itemsUpdated += 1

                } catch {
                    itemsFailed += 1
                    log.error("Failed to update tool \(updatePair.existing.stable_id): \(error)")
                }
            }

            // Brief pause between update batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return ToolUpdateResult(
            itemsUpdated: itemsUpdated,
            itemsFailed: itemsFailed
        )
    }

    /// Log the final loading results
    private func logLoadingResults(_ result: ToolLoadingResult, manufacturer: String) {
        log.info("=== Tool Loading Results for \(manufacturer) ===")
        log.info("Items Created: \(result.itemsCreated)")
        log.info("Items Updated: \(result.itemsUpdated)")
        log.info("Items Failed: \(result.itemsFailed)")
        log.info("Items Skipped: \(result.itemsSkipped)")

        if !result.failedItems.isEmpty {
            log.warning("Failed items:")
            for (index, failed) in result.failedItems.prefix(5).enumerated() {
                let sku = failed.sku ?? "NO_SKU"
                log.warning("  \(index + 1). \(failed.name) (\(sku)): \(failed.failureReason)")
            }
            if result.failedItems.count > 5 {
                log.warning("  ... and \(result.failedItems.count - 5) more")
            }
        }

        log.info("=== End Loading Results ===")
    }
}

// MARK: - Result Models

/// Results of a Tool loading operation
struct ToolLoadingResult {
    var itemsCreated: Int = 0
    var itemsFailed: Int = 0
    var itemsSkipped: Int = 0
    var itemsUpdated: Int = 0
    var successfulItems: [ToolItemModel] = []
    var failedItems: [FailedToolItem] = []

    /// Merge another result into this one
    mutating func merge(_ other: ToolLoadingResult) {
        itemsCreated += other.itemsCreated
        itemsFailed += other.itemsFailed
        itemsSkipped += other.itemsSkipped
        itemsUpdated += other.itemsUpdated
        successfulItems.append(contentsOf: other.successfulItems)
        failedItems.append(contentsOf: other.failedItems)
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

/// Information about a failed tool item creation
struct FailedToolItem {
    let name: String
    let sku: String?
    let error: Error
    let failureReason: String
}

/// Result of comparing JSON data with existing tools
struct ToolComparisonResult {
    let toCreate: [ToolJSONItem]      // Items that don't exist yet
    let toUpdate: [ToolUpdatePair]    // Items that exist but have changed
    let unchanged: [ToolItemModel]    // Items that exist and haven't changed
}

/// Pair of items for updating - old and new data
struct ToolUpdatePair {
    let existing: ToolItemModel
    let updated: ToolJSONItem
    let differences: [String]  // Description of what changed
}

/// Result of processing updates
struct ToolUpdateResult {
    let itemsUpdated: Int
    let itemsFailed: Int
}

// MARK: - JSON Data Models

/// Root structure for tools JSON file
struct ToolsJSONData: Codable {
    let manufacturer: String
    let manufacturer_name: String
    let manufacturer_url: String
    let last_updated: String
    let tools: [ToolJSONItem]
}

/// Individual tool item from JSON
struct ToolJSONItem: Codable {
    let name: String
    let sku: String?
    let category: String?
    let price: Double?
    let status: String?
}

// MARK: - Error Definitions

enum ToolItemDataLoadingError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(Error)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let manufacturer):
            return "Tool data file not found for manufacturer: \(manufacturer)"
        case .decodingFailed(let error):
            return "Failed to decode tool data: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid tool data: \(message)"
        }
    }
}
