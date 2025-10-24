//
//  InventoryImportService.swift
//  Molten
//
//  Service for importing inventory from JSON files created by the web import tool
//

import Foundation

/// Import mode determines how to handle existing inventory
enum InventoryImportMode: String, CaseIterable, Identifiable {
    case eraseAndReplace = "erase_replace"
    case addNewOnly = "add_new"
    case addAndIncrease = "add_increase"
    case askPerItem = "ask_per_item"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eraseAndReplace:
            return "Erase All & Replace"
        case .addNewOnly:
            return "Add New Items Only"
        case .addAndIncrease:
            return "Add New & Increase Existing"
        case .askPerItem:
            return "Ask for Each Item"
        }
    }

    var description: String {
        switch self {
        case .eraseAndReplace:
            return "Delete all existing inventory and import from scratch"
        case .addNewOnly:
            return "Only import items that don't exist in your inventory"
        case .addAndIncrease:
            return "Import new items and add quantities to existing items"
        case .askPerItem:
            return "Review each conflict and decide what to do"
        }
    }

    var icon: String {
        switch self {
        case .eraseAndReplace:
            return "trash.circle.fill"
        case .addNewOnly:
            return "plus.circle.fill"
        case .addAndIncrease:
            return "arrow.up.circle.fill"
        case .askPerItem:
            return "questionmark.circle.fill"
        }
    }
}

/// Action to take for an item when in interactive mode
enum ImportItemAction {
    case skip
    case replace
    case increase
}

/// Delegate for interactive import decisions
@MainActor
protocol InventoryImportDelegate {
    /// Ask user what to do with an item that already exists
    func shouldImportItem(_ item: ImportItem, existing: InventoryModel) async -> ImportItemAction
}

/// Service for importing inventory from JSON
class InventoryImportService {
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let locationRepository: LocationRepository

    var delegate: InventoryImportDelegate?

    init(catalogService: CatalogService, inventoryTrackingService: InventoryTrackingService, locationRepository: LocationRepository) {
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.locationRepository = locationRepository
    }

    /// Import inventory from a JSON file
    /// - Parameters:
    ///   - fileURL: URL to the JSON file
    ///   - mode: Import mode determining how to handle existing inventory
    /// - Returns: Result with count of successfully imported items
    func importInventory(from fileURL: URL, mode: InventoryImportMode) async throws -> ImportResult {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Read JSON data
        let jsonData = try Data(contentsOf: fileURL)
        let importData = try decodeImportData(jsonData)

        // Validate version
        guard importData.version == "1.0" else {
            throw InventoryImportError.unsupportedVersion(importData.version)
        }

        // If erase mode, delete all existing inventory first
        if mode == .eraseAndReplace {
            try await eraseAllInventory()
        }

        var successCount = 0
        var skippedCount = 0
        var failedItems: [(code: String, error: String)] = []

        // Process each item
        for item in importData.items {
            do {
                let wasImported = try await importItem(item, mode: mode)
                if wasImported {
                    successCount += 1
                } else {
                    skippedCount += 1
                }
            } catch {
                failedItems.append((code: item.code, error: error.localizedDescription))
            }
        }

        return ImportResult(
            totalItems: importData.items.count,
            successCount: successCount,
            skippedCount: skippedCount,
            failedItems: failedItems
        )
    }

    /// Preview import data without actually importing
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: Preview information
    func previewImport(from fileURL: URL) async throws -> ImportPreview {
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let jsonData = try Data(contentsOf: fileURL)
        let importData = try decodeImportData(jsonData)

        // Get file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0

        // Group by manufacturer
        let byManufacturer = Dictionary(grouping: importData.items) { $0.manufacturer }
        let manufacturerCounts = byManufacturer.map { (manufacturer: $0.key, count: $0.value.count) }
            .sorted { $0.manufacturer < $1.manufacturer }

        return ImportPreview(
            version: importData.version,
            itemCount: importData.items.count,
            dateGenerated: importData.generated,
            fileSize: fileSize,
            manufacturerBreakdown: manufacturerCounts
        )
    }

    // MARK: - Private Helpers

    /// Decode import data from JSON
    private func decodeImportData(_ data: Data) throws -> InventoryImportData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(InventoryImportData.self, from: data)
        } catch {
            throw InventoryImportError.invalidJSON(error.localizedDescription)
        }
    }

    /// Erase all existing inventory (including locations)
    private func eraseAllInventory() async throws {
        // Get all inventory records
        let allInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)

        // Delete each inventory record (this should cascade delete locations)
        for inventory in allInventory {
            try await inventoryTrackingService.inventoryRepository.deleteInventory(id: inventory.id)
        }
    }

    /// Import a single item
    /// - Parameters:
    ///   - item: Item to import
    ///   - mode: Import mode
    /// - Returns: true if item was imported, false if skipped
    private func importItem(_ item: ImportItem, mode: InventoryImportMode) async throws -> Bool {
        // Look up the glass item by stable_id (code)
        let searchRequest = GlassItemSearchRequest(
            searchText: item.code,
            manufacturers: [],
            coeValues: [],
            sortBy: .name,
            offset: 0,
            limit: 1
        )

        let searchResult = try await catalogService.searchGlassItems(request: searchRequest)

        guard let glassItem = searchResult.items.first?.glassItem,
              glassItem.stable_id == item.code else {
            throw InventoryImportError.itemNotFound(item.code)
        }

        // Check if inventory already exists for this item with this type
        let existingInventory = try await inventoryTrackingService.inventoryRepository
            .fetchInventory(forItem: glassItem.stable_id)
            .first { $0.type == item.type }

        // Handle based on mode
        if let existing = existingInventory {
            return try await handleExistingItem(item, glassItem: glassItem, existing: existing, mode: mode)
        } else {
            // No existing inventory - create new
            return try await createNewInventory(item, glassItem: glassItem)
        }
    }

    /// Handle importing an item that already exists
    private func handleExistingItem(_ item: ImportItem, glassItem: GlassItemModel, existing: InventoryModel, mode: InventoryImportMode) async throws -> Bool {
        switch mode {
        case .eraseAndReplace:
            // Already erased, so create new
            return try await createNewInventory(item, glassItem: glassItem)

        case .addNewOnly:
            // Skip existing items
            return false

        case .addAndIncrease:
            // Increase quantity using repository method
            _ = try await inventoryTrackingService.inventoryRepository.addQuantity(
                Double(item.quantity),
                toItem: glassItem.stable_id,
                type: item.type
            )

            // Update location if provided
            if let location = item.location, !location.isEmpty {
                try await locationRepository.setLocations(
                    [(location: location, quantity: Double(item.quantity))],
                    forInventory: existing.id
                )
            }
            return true

        case .askPerItem:
            // Ask delegate what to do
            guard let delegate = delegate else {
                // No delegate - default to skip
                return false
            }

            let action = await delegate.shouldImportItem(item, existing: existing)

            switch action {
            case .skip:
                return false

            case .replace:
                // Delete existing and create new
                try await inventoryTrackingService.inventoryRepository.deleteInventory(id: existing.id)
                return try await createNewInventory(item, glassItem: glassItem)

            case .increase:
                // Same as addAndIncrease mode - use repository method
                _ = try await inventoryTrackingService.inventoryRepository.addQuantity(
                    Double(item.quantity),
                    toItem: glassItem.stable_id,
                    type: item.type
                )

                if let location = item.location, !location.isEmpty {
                    try await locationRepository.setLocations(
                        [(location: location, quantity: Double(item.quantity))],
                        forInventory: existing.id
                    )
                }
                return true
            }
        }
    }

    /// Create new inventory record for an item
    private func createNewInventory(_ item: ImportItem, glassItem: GlassItemModel) async throws -> Bool {
        // Create inventory record with type and quantity from import
        let inventoryModel = InventoryModel(
            id: UUID(),
            item_stable_id: glassItem.stable_id,
            type: item.type,
            quantity: Double(item.quantity),
            date_added: Date(),
            date_modified: Date()
        )

        // Save using inventory tracking service
        let createdInventory = try await inventoryTrackingService.inventoryRepository.createInventory(inventoryModel)

        // Associate location if provided
        if let location = item.location, !location.isEmpty {
            try await locationRepository.setLocations(
                [(location: location, quantity: Double(item.quantity))],
                forInventory: createdInventory.id
            )
        }

        return true
    }
}

// MARK: - Data Models

/// Import data structure (matches web export format)
struct InventoryImportData: Codable {
    let version: String
    let generated: Date
    let items: [ImportItem]
}

/// Single item in import list
struct ImportItem: Codable {
    let code: String  // This is the stable_id (e.g., "2wjEBu") NOT the product code (e.g., "BB-01-T-Mead")
    let name: String
    let manufacturer: String
    let type: String
    let quantity: Int
    let location: String?
}

/// Preview information
struct ImportPreview {
    let version: String
    let itemCount: Int
    let dateGenerated: Date
    let fileSize: Int64
    let manufacturerBreakdown: [(manufacturer: String, count: Int)]

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateGenerated)
    }
}

/// Import result
struct ImportResult {
    let totalItems: Int
    let successCount: Int
    let skippedCount: Int
    let failedItems: [(code: String, error: String)]

    var hasFailures: Bool {
        !failedItems.isEmpty
    }

    var successRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(successCount) / Double(totalItems)
    }
}

// MARK: - Errors

enum InventoryImportError: LocalizedError {
    case invalidJSON(String)
    case unsupportedVersion(String)
    case itemNotFound(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let reason):
            return "Could not read import file: \(reason)"
        case .unsupportedVersion(let version):
            return "Unsupported file version: \(version). Please use the latest import tool."
        case .itemNotFound(let code):
            return "Glass item not found: \(code)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
}
