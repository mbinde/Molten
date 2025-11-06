//
//  CoatingItemDataLoadingService.swift
//  Molten
//
//  Service for loading coating data from JSON file into the CoatingItem system
//

import Foundation
import OSLog

/// Service for loading data from JSON file into the CoatingItem system
/// Handles transformation from JSON format to the normalized entity structure
/// Supports initial loading and bulk import operations
@preconcurrency
class CoatingItemDataLoadingService {

    // MARK: - Dependencies

    nonisolated private let coatingRepository: CoatingItemRepository
    private let log = Logger(subsystem: "Molten", category: "CoatingItemDataLoading")

    // MARK: - JSON Checksum Support

    /// Store JSON file checksum in UserDefaults for change detection
    private struct JSONChecksum: Codable {
        let modificationDate: Date
        let fileSize: Int64
    }

    private static let checksumKey = "com.molten.coatings.json.checksum"

    /// Check if JSON file has changed since last load
    /// Returns true if file has changed or is first run, false if unchanged
    func hasJSONFileChanged() throws -> Bool {
        // Get file attributes to compute checksum
        guard let filePath = Bundle.main.path(forResource: "coatings", ofType: "json") else {
            log.warning("Could not find coatings.json file path, assuming changed")
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
                log.info("🔄 Detected JSON file change for coatings (mod date or size changed)")
            } else {
                log.info("✅ JSON file unchanged for coatings since last load, skipping")
            }

            return hasChanged
        } else {
            log.info("🆕 First run or no checksum found for coatings, will load JSON")
            return true
        }
    }

    /// Save current JSON file checksum to UserDefaults after successful load
    func saveJSONChecksum() throws {
        guard let filePath = Bundle.main.path(forResource: "coatings", ofType: "json") else {
            log.warning("Could not find coatings.json file path, cannot save checksum")
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

        log.info("💾 Saved JSON checksum for coatings (size: \(fileSize) bytes, modified: \(modificationDate))")
    }

    // MARK: - Configuration

    /// Options for controlling the data loading behavior
    struct LoadingOptions {
        let skipExistingItems: Bool
        let validateStableIds: Bool
        let batchSize: Int

        static let `default` = LoadingOptions(
            skipExistingItems: true,
            validateStableIds: true,
            batchSize: 50
        )

        static let testing = LoadingOptions(
            skipExistingItems: false,
            validateStableIds: true,
            batchSize: 10
        )

        /// Option for app updates - processes all items and updates any that have changed
        static let appUpdate = LoadingOptions(
            skipExistingItems: false,
            validateStableIds: true,
            batchSize: 25
        )
    }

    // MARK: - Initialization

    nonisolated init(coatingRepository: CoatingItemRepository) {
        self.coatingRepository = coatingRepository
    }

    // MARK: - Public API

    /// Load coatings from JSON file
    /// - Parameter options: Configuration options for loading behavior
    /// - Returns: Results of the loading operation
    func loadCoatingsFromJSON(options: LoadingOptions = .default) async throws -> CoatingLoadingResult {
        log.info("Starting Coating data loading from JSON")

        // Load and decode JSON data
        guard let data = loadJSONData() else {
            throw CoatingItemDataLoadingError.fileNotFound
        }

        let coatingsData = try decodeCoatingsData(from: data)

        log.info("Loaded \(coatingsData.coatings.count) coatings from JSON")

        // Get existing items for comparison
        let existingItems = try await coatingRepository.fetchItems(matching: nil)
        log.info("Found \(existingItems.count) existing coatings in database")

        // Compare and categorize items
        let comparisonResult = compareAndCategorizeItems(
            jsonCoatings: coatingsData.coatings,
            existingItems: existingItems,
            options: options
        )

        log.info("Comparison complete: \(comparisonResult.toCreate.count) to create, \(comparisonResult.toUpdate.count) to update, \(comparisonResult.unchanged.count) unchanged")

        // Process creates and updates
        var results = CoatingLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        // Process new items (creates)
        if !comparisonResult.toCreate.isEmpty {
            log.info("Creating \(comparisonResult.toCreate.count) new coatings")
            let createResults = try await processCreates(
                comparisonResult.toCreate,
                options: options
            )
            results.merge(createResults)
        }

        // Process updated items
        if !comparisonResult.toUpdate.isEmpty {
            log.info("Updating \(comparisonResult.toUpdate.count) changed coatings")
            let updateResults = try await processUpdates(comparisonResult.toUpdate, options: options)
            results.itemsUpdated = updateResults.itemsUpdated
            results.itemsFailed += updateResults.itemsFailed
        }

        // Count unchanged items as skipped
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

    // MARK: - Private Implementation

    /// Load JSON data from bundle
    private func loadJSONData() -> Data? {
        guard let path = Bundle.main.path(forResource: "coatings", ofType: "json") else {
            log.error("Could not find coatings.json in bundle")
            return nil
        }

        do {
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            log.error("Failed to load JSON data: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decode coatings data from JSON
    private func decodeCoatingsData(from data: Data) throws -> CoatingsJSONData {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CoatingsJSONData.self, from: data)
        } catch {
            log.error("Failed to decode coatings JSON: \(error.localizedDescription)")
            throw CoatingItemDataLoadingError.decodingFailed(error)
        }
    }

    /// Compare JSON coatings with existing coatings and categorize them
    private func compareAndCategorizeItems(
        jsonCoatings: [CoatingJSONItem],
        existingItems: [CoatingItemModel],
        options: LoadingOptions
    ) -> CoatingComparisonResult {

        // Create lookup dictionary for existing items by stable_id
        let existingByStableId = Dictionary(uniqueKeysWithValues:
            existingItems.map { ($0.stable_id, $0) }
        )

        var toCreate: [CoatingJSONItem] = []
        var toUpdate: [CoatingUpdatePair] = []
        var unchanged: [CoatingItemModel] = []

        for jsonCoating in jsonCoatings {
            if let existingItem = existingByStableId[jsonCoating.stable_id] {
                // Item exists - check if it needs updating
                let differences = compareItems(existing: existingItem, jsonItem: jsonCoating)

                if differences.isEmpty {
                    unchanged.append(existingItem)
                } else {
                    let updatePair = CoatingUpdatePair(
                        existing: existingItem,
                        updated: jsonCoating,
                        differences: differences
                    )
                    toUpdate.append(updatePair)
                    log.info("Coating \(jsonCoating.stable_id) needs update: \(differences.joined(separator: ", "))")
                }
            } else {
                // Item doesn't exist - needs to be created
                toCreate.append(jsonCoating)
            }
        }

        return CoatingComparisonResult(
            toCreate: toCreate,
            toUpdate: toUpdate,
            unchanged: unchanged
        )
    }

    /// Compare an existing coating with JSON data to detect changes
    private func compareItems(existing: CoatingItemModel, jsonItem: CoatingJSONItem) -> [String] {
        var differences: [String] = []

        // Compare basic properties
        if existing.name != jsonItem.name {
            differences.append("name: '\(existing.name)' -> '\(jsonItem.name)'")
        }

        // Compare manufacturer
        if existing.manufacturer != jsonItem.manufacturer {
            differences.append("manufacturer: '\(existing.manufacturer)' -> '\(jsonItem.manufacturer)'")
        }

        return differences
    }

    /// Process items that need to be created
    private func processCreates(
        _ coatings: [CoatingJSONItem],
        options: LoadingOptions
    ) async throws -> CoatingLoadingResult {
        var results = CoatingLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        let batches = stride(from: 0, to: coatings.count, by: options.batchSize).map {
            Array(coatings[$0..<min($0 + options.batchSize, coatings.count)])
        }

        for batch in batches {
            for jsonCoating in batch {
                do {
                    // Create coating item model
                    let coatingItem = CoatingItemModel(
                        stable_id: jsonCoating.stable_id,
                        name: jsonCoating.name,
                        sku: jsonCoating.code,
                        manufacturer: jsonCoating.manufacturer,
                        mfr_notes: jsonCoating.manufacturer_description,
                        url: jsonCoating.manufacturer_url,
                        mfr_status: "available",
                        image_url: jsonCoating.image_url.isEmpty ? nil : jsonCoating.image_url,
                        image_path: jsonCoating.image_path.isEmpty ? nil : jsonCoating.image_path
                    )

                    let createdItem = try await coatingRepository.createItem(coatingItem)
                    results.successfulItems.append(createdItem)
                    results.itemsCreated += 1

                } catch {
                    let failedItem = FailedCoatingItem(
                        name: jsonCoating.name,
                        stableId: jsonCoating.stable_id,
                        error: error,
                        failureReason: error.localizedDescription
                    )
                    results.failedItems.append(failedItem)
                    results.itemsFailed += 1
                    log.error("Failed to create coating: \(error.localizedDescription)")
                }
            }

            // Brief pause between batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return results
    }

    /// Process items that need to be updated
    private func processUpdates(_ updates: [CoatingUpdatePair], options: LoadingOptions) async throws -> CoatingUpdateResult {
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
                    // Create updated CoatingItemModel from JSON data
                    let updatedItem = CoatingItemModel(
                        stable_id: updatePair.existing.stable_id,
                        name: updatePair.updated.name,
                        sku: updatePair.updated.code,
                        manufacturer: updatePair.updated.manufacturer,
                        mfr_notes: updatePair.updated.manufacturer_description,
                        url: updatePair.updated.manufacturer_url,
                        mfr_status: updatePair.existing.mfr_status,
                        image_url: updatePair.updated.image_url.isEmpty ? nil : updatePair.updated.image_url,
                        image_path: updatePair.updated.image_path.isEmpty ? nil : updatePair.updated.image_path
                    )

                    // Update the item
                    _ = try await coatingRepository.updateItem(updatedItem)
                    itemsUpdated += 1

                } catch {
                    itemsFailed += 1
                    log.error("Failed to update coating \(updatePair.existing.stable_id): \(error)")
                }
            }

            // Brief pause between update batches
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return CoatingUpdateResult(
            itemsUpdated: itemsUpdated,
            itemsFailed: itemsFailed
        )
    }

    /// Log the final loading results
    private func logLoadingResults(_ result: CoatingLoadingResult) {
        log.info("=== Coating Loading Results ===")
        log.info("Items Created: \(result.itemsCreated)")
        log.info("Items Updated: \(result.itemsUpdated)")
        log.info("Items Failed: \(result.itemsFailed)")
        log.info("Items Skipped: \(result.itemsSkipped)")

        if !result.failedItems.isEmpty {
            log.warning("Failed items:")
            for (index, failed) in result.failedItems.prefix(5).enumerated() {
                log.warning("  \(index + 1). \(failed.name) (\(failed.stableId)): \(failed.failureReason)")
            }
            if result.failedItems.count > 5 {
                log.warning("  ... and \(result.failedItems.count - 5) more")
            }
        }

        log.info("=== End Loading Results ===")
    }
}

// MARK: - Result Models

/// Results of a Coating loading operation
struct CoatingLoadingResult {
    var itemsCreated: Int = 0
    var itemsFailed: Int = 0
    var itemsSkipped: Int = 0
    var itemsUpdated: Int = 0
    var successfulItems: [CoatingItemModel] = []
    var failedItems: [FailedCoatingItem] = []

    /// Merge another result into this one
    mutating func merge(_ other: CoatingLoadingResult) {
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

/// Information about a failed coating item creation
struct FailedCoatingItem {
    let name: String
    let stableId: String
    let error: Error
    let failureReason: String
}

/// Result of comparing JSON data with existing coatings
struct CoatingComparisonResult {
    let toCreate: [CoatingJSONItem]         // Items that don't exist yet
    let toUpdate: [CoatingUpdatePair]       // Items that exist but have changed
    let unchanged: [CoatingItemModel]       // Items that exist and haven't changed
}

/// Pair of items for updating - old and new data
struct CoatingUpdatePair {
    let existing: CoatingItemModel
    let updated: CoatingJSONItem
    let differences: [String]  // Description of what changed
}

/// Result of processing updates
struct CoatingUpdateResult {
    let itemsUpdated: Int
    let itemsFailed: Int
}

// MARK: - JSON Data Models

/// Root structure for coatings JSON file
struct CoatingsJSONData: Codable {
    let version: String
    let generated: String
    let item_count: Int
    let coatings: [CoatingJSONItem]
}

/// Individual coating item from JSON
struct CoatingJSONItem: Codable {
    let stable_id: String
    let code: String
    let name: String
    let manufacturer: String
    let manufacturer_description: String
    let tags: String
    let image_url: String
    let image_path: String
    let manufacturer_url: String
    let product_type: String
    let coe: String
}

// MARK: - Error Definitions

enum CoatingItemDataLoadingError: Error, LocalizedError {
    case fileNotFound
    case decodingFailed(Error)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Coating data file not found (coatings.json)"
        case .decodingFailed(let error):
            return "Failed to decode coating data: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid coating data: \(message)"
        }
    }
}
