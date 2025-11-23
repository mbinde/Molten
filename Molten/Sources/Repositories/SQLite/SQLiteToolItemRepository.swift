//
//  SQLiteToolItemRepository.swift
//  Molten
//
//  SQLite-based implementation for ToolItemModel using generic base class
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for catalog tool items
final class SQLiteToolItemRepository: BaseSQLiteCatalogItemRepository<ToolItemModel>, @unchecked Sendable {

    // MARK: - Initialization

    nonisolated init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        super.init(
            databaseManager: databaseManager,
            tableName: "tools",
            orderByColumns: "manufacturer, name"
        )
    }

    // MARK: - Manufacturer Filtering

    /// Filter out manufacturers that shouldn't ship with the bundled catalog
    private func filterByShippedManufacturers(_ items: [ToolItemModel]) -> [ToolItemModel] {
        return items.filter { item in
            GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer)
        }
    }

    // MARK: - Overridden Methods with Feature Flags and Manufacturer Filtering

    override func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
        guard FeatureFlags.ENABLE_TOOLS else {
            return [] // Return empty array when tools are disabled
        }
        let items = try await super.fetchItems(matching: predicate)
        return filterByShippedManufacturers(items)
    }

    override func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        guard FeatureFlags.ENABLE_TOOLS else {
            return nil // Return nil when tools are disabled
        }
        guard let item = try await super.fetchItem(byStableId: stableId) else {
            return nil
        }
        return GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer) ? item : nil
    }

    override func searchItems(text: String) async throws -> [ToolItemModel] {
        guard FeatureFlags.ENABLE_TOOLS else {
            return [] // Return empty array when tools are disabled
        }

        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM tools
            WHERE name LIKE ? OR manufacturer LIKE ? OR description LIKE ?
            ORDER BY manufacturer, name
            """

        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern])
        }
        return filterByShippedManufacturers(items)
    }

    override func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        guard FeatureFlags.ENABLE_TOOLS else {
            return []
        }
        // Check if this manufacturer should even be queried
        guard GlassManufacturers.shipsWithBundledCatalog(for: manufacturer) else {
            return []
        }
        return try await super.fetchItems(byManufacturer: manufacturer)
    }

    // MARK: - Tool-Specific Parsing

    /// Parse a ToolItemModel from a SQLite row
    nonisolated override func parseItem(from statement: OpaquePointer) throws -> ToolItemModel {
        // Column indices from schema:
        // 0=stable_id, 1=name, 2=sku, 3=description, 4=price, 5=category,
        // 6=image_url, 7=product_url, 8=status, 9=manufacturer

        guard let stable_id = getText(from: statement, column: 0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(from: statement, column: 1) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(from: statement, column: 9) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let sku = getText(from: statement, column: 2)
        let mfr_notes = getText(from: statement, column: 3)  // description -> mfr_notes
        let url = getText(from: statement, column: 7)  // product_url -> url
        let mfr_status = getText(from: statement, column: 8) ?? "available"  // status -> mfr_status
        let image_url = getText(from: statement, column: 6)
        let image_path: String? = nil  // Not in database

        return ToolItemModel(
            stable_id: stable_id,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path
        )
    }
}
