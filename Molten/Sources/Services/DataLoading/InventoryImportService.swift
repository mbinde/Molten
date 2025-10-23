//
//  InventoryImportService.swift
//  Molten
//
//  Service for importing inventory from JSON files created by the web import tool
//

import Foundation

/// Service for importing inventory from JSON
class InventoryImportService {
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService

    init(catalogService: CatalogService, inventoryTrackingService: InventoryTrackingService) {
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
    }

    /// Import inventory from a JSON file
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: Result with count of successfully imported items
    func importInventory(from fileURL: URL) async throws -> ImportResult {
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

        var successCount = 0
        var failedItems: [(code: String, error: String)] = []

        // Process each item
        for item in importData.items {
            do {
                try await importItem(item)
                successCount += 1
            } catch {
                failedItems.append((code: item.code, error: error.localizedDescription))
            }
        }

        return ImportResult(
            totalItems: importData.items.count,
            successCount: successCount,
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

    /// Import a single item
    private func importItem(_ item: ImportItem) async throws {
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

        // Create inventory record
        // For simplicity, create as "rods" type with the specified quantity
        // Users can edit the type and add location details later
        let inventoryModel = InventoryModel(
            id: UUID(),
            item_stable_id: glassItem.stable_id,
            type: "rods",
            quantity: Double(item.quantity),
            date_added: Date(),
            date_modified: Date()
        )

        // Save using inventory tracking service
        _ = try await inventoryTrackingService.inventoryRepository.createInventory(inventoryModel)
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
    let code: String
    let name: String
    let manufacturer: String
    let coe: String
    let type: String
    let quantity: Int
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
